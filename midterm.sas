GOPTIONS reset=all;
GOPTIONS
CBACK=BlanchedAlmond
CBY=Tomato
CPATTERN=IndianRed
CSYMBOL=FireBrick;

PROC IMPORT OUT= work.ppdata1 
			DATAFILE = "C:\Users\schechter\Desktop\MIDTERM\ppdatanum.xls" 
			DBMS = xls REPLACE;
            SHEET = "Sheet1";
	 		GETNAMES = YES;
RUN;

/* What kind of variables are these? I run FREQ here just to see what the variable names are.  I looked up what they mean on trackmaster.com*/
/* There are 10 races in each horse's history.  Let's remove all of the ds races, then model the 2nd-to-last race based on the previous race, gait, cond, age, */

PROC FREQ DATA = work.ppdata1;
	TABLES cond;
RUN;

/********Creating a 1-record-per-race data set to investigate the difference in speed between Pacers and Trotters and between "Fast" and "Sloppy" Conditions */
/* Note, these variablse are the same for every horse in the race, so the set should have one observation per race. */

DATA work.cond;
  SET work.ppdata1;
  KEEP lead_tm_fn cond racenum track date gait;
  LABEL lead_tm_fn="Lead Horse Final Time";
RUN;

/* Sort the data uniquely by race.  In this data set, a unique race is racenum-track-date.*/
PROC SORT DATA=work.cond nodupkey;
	BY track racenum date;
RUN;

/* Tell me about my data!  Are my data normal? My variable of interest is the lead_tm_fn - Lead Time Final - The winning horse's final time.*/

PROC UNIVARIATE DATA = work.cond NORMAL PLOT;
	TITLE "Checking for Normality of Final Race Time for Lead Horse";
	VAR lead_tm_fn ;
	Histogram lead_tm_fn /normal ctext=CXFFFFD4;
RUN;


/* The low p-value for the Shapiro-Wilk test says that my data do NOT come from a normal distribution. */
/* What are these races that are taking 160 seconds or more?  That seems EXTREME. */

DATA work.cond_subset;
   SET work.cond;
   WHERE lead_tm_fn > 160;
RUN;

PROC PRINT DATA=work.cond_subset;
	TITLE "The Extreme Observations";
RUN;

/* So let's remove these extreme observations from the data set */

DATA work.cond2;
  SET work.cond;
  IF lead_tm_fn > 160 then delete;
RUN;

/* Run proc univariate again */
/* From thsese results you see that the data is much closer to normal, WS doesn't confirm this.  */

PROC UNIVARIATE DATA = work.cond2 NORMAL PLOT;
	TITLE "Descriptive Statistics Of Race Time After Removing Extreme Observations";
	VAR lead_tm_fn;
	Histogram lead_tm_fn /normal ctext=CXFFFFD4;
RUN;

/* Look at the mean race time for each gait. */

PROC MEANS DATA = work.cond2 MAXDEC=1 NWAY;
	TITLE "Mean Race Time, by Gait (Pacers vs. Trotters)";
	CLASS gait;
	VAR lead_tm_fn;
RUN;

/* Is this significant? */
PROC TTEST DATA = work.cond2;
	TITLE "T-Test of Difference in Mean Race Time, by Gait(Pacers vs. Trotters)";
	CLASS gait;
	VAR lead_tm_fn;
RUN;

/* Look at the mean race time for each track condition. */

PROC MEANS DATA = work.cond2 MAXDEC=1 NWAY;
	TITLE "Mean Race Time, by Condition (Fast, Good, and Sloppy)";
	CLASS cond;
	VAR lead_tm_fn;
RUN;

/* Is the difference between Fast and Sloppy significant? (We need to limit our data to just that)*/

PROC TTEST DATA = work.cond2;
	CLASS cond;
	WHERE cond = "FT" or cond = "SY";
	VAR lead_tm_fn;
RUN;

/*********************Correlation Coefficients Between Calls at Each Quarter and Final Time ********************************/
/*  Motivation:  Oftentimes the winning horse will hang in the back before passing a bunch of other horses to win.  I want to know more about this. */
/* For this analysis I'll use all the races from all the horses, not just one observation per race. */

/* This is just to help me see the variables in my data set. */
PROC CONTENTS DATA = work.ppdata1;
RUN;


DATA work.qcalls;
  SET work.ppdata1;
  KEEP call_1q_lb call_2q_lb call_3q_lb call_fn_lb ;
RUN;
/*##1####################################################################################################################*/
/* Some of the values are abbreviations for parts of the horse rather than numbers.  I want to see all of these. */

/*First I need to concatenate a data set */
DATA work.qcalls1;
  SET work.qcalls (RENAME=(call_1q_lb=call))
    work.qcalls (RENAME=(call_2q_lb=call))
	work.qcalls (RENAME=(call_3q_lb=call))
	work.qcalls (RENAME=(call_fn_lb=call));
	KEEP call;
RUN;

/*Then I need to sort my concatenated data set, keeping only non-numeric values*/

PROC SORT DATA=work.qcalls1 (KEEP=call WHERE=(ANYALPHA(call) > 0)) nodupkey OUT=work.qcalls2;
	BY call;
RUN;

PROC PRINT DATA=work.qcalls2;
	TITLE 'The Unique Non-Numeric Values of Quarter-Call and Final-Call variables';
RUN;

/* Now I need to relabel those values numerically.  What are they worth? */
/* Our smallest measurement before horse bits is 1/4, so let's call a neck 1/8, a head 1/16, and a nose 0 */
/* But what about "ds" = distance? How far back is that?  Online it says '30 lengths or more', but that seems long to me.  Maybe we should just set it a bit longer than the longest numeric distance in the data set."
/* First let's check how many observations we have with each. */

PROC FREQ DATA=work.qcalls1 (KEEP=call WHERE=(ANYALPHA(call) > 0));
	TABLES call;
	TITLE 'Number of Appearance of Each Non-numeric Value of Quarter-Call and Final-Call variables';
RUN;

/* I want to run proc means, but the numeric variable is currently coded as a string, so first I need to convert to a numeric variable */
/* Trick - multiply by 1! */
DATA work.qcalls3;
  SET work.qcalls1;
  	IF(ANYALPHA(call) = 0);
    	call2=call*1;
	KEEP call2;
RUN;

PROC MEANS DATA=work.qcalls3;
	VAR call2;
	TITLE 'PROC MEANS TO FIND MAX OF CALL VARIABLES';
RUN;
/*########################################################################################################*/
/* But wait!  Let's make sure that we don't have OUTLIERS! */
PROC UNIVARIATE DATA=work.qcalls3 NORMAL PLOT;
	TITLE 'Lengths Back in all Calls - Finding Extremes';
	VAR call2;
RUN;

/* The highest observations were at 50, but very few observations were more than 30, and this agrees with what I've read about "distance", so let's recode all ds and all values greater than 30 to 30. */
/* Finally! Making the data set I'll use for correlations! */
DATA work.qcalls;
  SET work.ppdata1;
  	IF (call_1q_lb = 'ns') THEN _call_1q_lb = 0;
	IF (call_1q_lb = 'hd') THEN _call_1q_lb = 0.0625;
	IF (call_1q_lb = 'nk') THEN _call_1q_lb = 0.125;
	IF (call_1q_lb = 'ds') THEN _call_1q_lb = 30;
	IF (call_1q_lb*1 > 30) THEN _call_1q_lb = 30;
	IF (_call_1q_lb = ' ') THEN _call_1q_lb = call_1q_lb;
	IF (call_2q_lb = 'ns') THEN _call_2q_lb = 0;
	IF (call_2q_lb = 'hd') THEN _call_2q_lb = 0.0625;
	IF (call_2q_lb = 'nk') THEN _call_2q_lb = 0.125;
	IF (call_2q_lb = 'ds') THEN _call_2q_lb = 30;
	IF (call_2q_lb*1 > 30) THEN _call_2q_lb = 30;
	IF (_call_2q_lb = ' ') THEN _call_2q_lb = call_2q_lb;
	IF (call_3q_lb = 'ns') THEN _call_3q_lb = 0;
	IF (call_3q_lb = 'hd') THEN _call_3q_lb = 0.0625;
	IF (call_3q_lb = 'nk') THEN _call_3q_lb = 0.125;
	IF (call_3q_lb = 'ds') THEN _call_3q_lb = 30;
	IF (call_3q_lb*1 > 30) THEN _call_3q_lb = 30;
	IF (_call_3q_lb = ' ') THEN _call_3q_lb = call_3q_lb;
	IF (call_fn_lb = 'ns') THEN _call_fn_lb = 0;
	IF (call_fn_lb = 'hd') THEN _call_fn_lb = 0.0625;
	IF (call_fn_lb = 'nk') THEN _call_fn_lb = 0.125;
	IF (call_fn_lb = 'ds') THEN _call_fn_lb = 30;
	IF (call_fn_lb*1 > 30) THEN _call_fn_lb = 30;
	IF (_call_fn_lb = ' ') THEN _call_fn_lb = call_fn_lb;
  KEEP _call_1q_lb _call_2q_lb _call_3q_lb _call_fn_lb;
RUN;

/* Let's see how highly correlated each quarter's distance is to the final result! */
PROC CORR DATA=work.qcalls;
	TITLE "Correlation Between Distance Behind Lead at Each Quarter and Final Distance Behind Lead";
	VAR _call_fn_lb;
	WITH _call_1q_lb _call_2q_lb _call_3q_lb;
RUN;

/* What about just for winners? */
PROC MEANS DATA=work.qcalls(WHERE=(_call_fn_lb = 0));
	TITLE 'MEAN DISTANCE BEHIND THE LEAD AT EACH QUARTER';
	VAR _call_1q_lb _call_2q_lb _call_3q_lb;
RUN;

/* Wait something isn't right.  Maximum at 30? */
/* Let's demonstrate PROC SQL! */

PROC SQL;
  SELECT horse_name, track, racenum, cond, gait, hrse_tm_fn, lead_tm_fn, call_1q_lb, call_2q_lb, call_3q_lb, call_fn_lb FROM work.ppdata1
  WHERE ((call_3q_lb = 'ds' OR call_3q_lb = '30') and call_fn_lb = '0');

  PROC SQL;
  SELECT horse_name, track, racenum, cond, gait, hrse_tm_fn, lead_tm_fn, call_1q_lb, call_2q_lb, call_3q_lb, call_fn_lb, comment FROM work.ppdata1
  WHERE (call_fn_lb = '0');

  /* I misunderstood my data set!  ds seems to be disqualified. */

  PROC SQL;
  SELECT horse_name, track, racenum, cond, gait, hrse_tm_fn, lead_tm_fn, call_1q_lb, call_2q_lb, call_3q_lb, call_fn_lb, comment FROM work.ppdata1
  WHERE (call_1q_lb = 'ds' or call_2q_lb = 'ds' or call_3q_lb = 'ds' or call_fn_lb = 'ds');

/* discussion on rules of horse racing yielded this important data  

  depending on the race
a pace is when each side's legs touch at the same time
and a trot is when all four touch at different times
if you break into a gallop or a run
you must let other horses pass you
if you don't, at teh end of the race there will be an inquiry
and they can take you down to whatever position they feel is appropriate 

  */

  /* Time to rework this.  Which variable shows me the winner? */
  PROC SQL;
  SELECT call_fn_po, call_fn_lb, comment FROM work.ppdata1;
  PROC SQL;
  SELECT call_fn_po, call_fn_lb, comment FROM work.ppdata1 WHERE (call_fn_po = 1);
    PROC SQL;
  SELECT call_1q_po, call_1q_lb, call_2q_po, call_2q_lb, call_3q_po, call_3q_lb, call_fn_po, call_fn_lb, comment FROM work.ppdata1 WHERE (call_fn_po = 1);

  /* ds is "disqualified!"  We need to remove these observations from the data set.  Also, we need to include call_fn_po to show the winner*/

DATA work.qcalls;
  SET work.ppdata1;
  	IF (call_1q_lb = 'ns') THEN _call_1q_lb = 0;
	IF (call_1q_lb = 'hd') THEN _call_1q_lb = 0.0625;
	IF (call_1q_lb = 'nk') THEN _call_1q_lb = 0.125;
	IF (call_1q_lb = 'ds') THEN delete;
	IF (call_1q_lb*1 > 30) THEN _call_1q_lb = 30;
	IF (_call_1q_lb = ' ') THEN _call_1q_lb = call_1q_lb;
	IF (call_2q_lb = 'ns') THEN _call_2q_lb = 0;
	IF (call_2q_lb = 'hd') THEN _call_2q_lb = 0.0625;
	IF (call_2q_lb = 'nk') THEN _call_2q_lb = 0.125;
	IF (call_2q_lb = 'ds') THEN delete;
	IF (call_2q_lb*1 > 30) THEN _call_2q_lb = 30;
	IF (_call_2q_lb = ' ') THEN _call_2q_lb = call_2q_lb;
	IF (call_3q_lb = 'ns') THEN _call_3q_lb = 0;
	IF (call_3q_lb = 'hd') THEN _call_3q_lb = 0.0625;
	IF (call_3q_lb = 'nk') THEN _call_3q_lb = 0.125;
	IF (call_3q_lb = 'ds') THEN delete;
	IF (call_3q_lb*1 > 30) THEN _call_3q_lb = 30;
	IF (_call_3q_lb = ' ') THEN _call_3q_lb = call_3q_lb;
	IF (call_fn_lb = 'ns') THEN _call_fn_lb = 0;
	IF (call_fn_lb = 'hd') THEN _call_fn_lb = 0.0625;
	IF (call_fn_lb = 'nk') THEN _call_fn_lb = 0.125;
	IF (call_fn_lb = 'ds') THEN delete;
	IF (call_fn_lb*1 > 30) THEN _call_fn_lb = 30;
	IF (_call_fn_lb = ' ') THEN _call_fn_lb = call_fn_lb;
	IF (call_fn_lb*1 = 0) THEN delete;
KEEP _call_1q_lb _call_2q_lb _call_3q_lb _call_fn_lb call_fn_po;
LABEL  _call_1q_lb  ="Lengths Back at 1st Quarter Call"
		_call_2q_lb  ="Lengths Back at 2nd Quarter Call"
		_call_3q_lb  ="Lengths Back at 3rd Quarter Call"
		_call_fn_lb  ="Lengths Back at Final Call";
RUN;

/** Alright, now let's try it! */
/* Let's see how highly correlated each quarter's distance is to the final result! */
PROC CORR DATA=work.qcalls;
	TITLE "Correlation Between Distance Behind Lead at Each Quarter and Final Distance Behind Lead";
	VAR _call_fn_lb;
	WITH _call_1q_lb _call_2q_lb _call_3q_lb;
RUN;

/* What about just for winners? */
PROC CORR DATA=work.qcalls (WHERE=(call_fn_po = 1));
	TITLE "Correlation Between Distance Behind Lead at Each Quarter and Final Distance Behind Lead";
	VAR _call_fn_lb;
	WITH _call_1q_lb _call_2q_lb _call_3q_lb;
RUN;

/* Let's do a visual representation of this. */

PROC GPLOT DATA = work.qcalls;
	TITLE "Correlation Between Lengths Back at 1st Quarter and Final Lengths Back";
	PLOT _call_fn_lb*_call_1q_lb;
RUN; 

PROC GPLOT DATA = work.qcalls;
	TITLE "Correlation Between Lengths Back at 3rd Quarter and Final Lengths Back";
	PLOT _call_fn_lb*_call_3q_lb;
RUN; 

PROC GPLOT DATA = work.qcalls (WHERE=(call_fn_po = 1));
	TITLE "Correlation Between Lengths Back at 1st Quarter and Final Lengths Back - Winners";
	PLOT _call_fn_lb*_call_1q_lb;
RUN; 

PROC GPLOT DATA = work.qcalls (WHERE=(call_fn_po = 1));
	TITLE "Correlation Between Lengths Back at 3rd Quarter and Final Lengths Back - Winners";
	PLOT _call_fn_lb*_call_3q_lb;
RUN; 
/* There's still some weirdness here.  Looks like our data has a long tail! */
PROC UNIVARIATE DATA = work.qcalls (WHERE=(call_fn_po = 1)) NORMAL PLOT;
	TITLE "UNIVARIATE of Final Lengths Back for Winners";
	VAR _call_fn_lb;
RUN; 

/*Another wasy to visualize this is with sgscatter */

PROC SGSCATTER data=work.qcalls;
	TITLE "Correlation Between Lengths Back at Each Quarter Call and Final Lengths Back";
	compare x = (_call_1q_lb _call_2q_lb _call_3q_lb)
			y = (_call_fn_lb) /ELLIPSE;
	RUN;
	QUIT;

PROC SGSCATTER data=work.qcalls (WHERE=(call_fn_po = 1));
	TITLE "Correlation Between Lengths Back at Each Quarter Call and Final Lengths Back (Winners)";
	compare x = (_call_1q_lb _call_2q_lb _call_3q_lb)
			y = (_call_fn_lb) /ELLIPSE;
			RUN;
			QUIT;

/******************** Regression Analysis - Simple Example ************************************/
/* I'm going to merge my data set with another data set I created based on the xml file - one with metadata about the horses.
/*  Then, I'm going to show how speed changes with age */
/*##2######################################################################################################################*/
PROC IMPORT OUT= work.horsedata 
			DATAFILE = "C:\Users\schechter\Desktop\MIDTERM\horsedata.xls" 
			DBMS = xls REPLACE;
            SHEET = "Sheet1";
	 		GETNAMES = YES;
RUN;
/* SORT FIRST! */
PROC SORT DATA = work.horsedata (RENAME=(name=horse_name)) OUT=work.horsedatas;
	BY horse_name;
RUN;

PROC SORT DATA = work.ppdata1 OUT=work.ppdata1s;
	BY horse_name;
RUN;
/* KEEP ONLY VALUES IN HORSE DATA SET (which should be all)*/
DATA work.speedage;
	MERGE work.ppdata1s work.horsedatas (IN=FRODO);
	BY horse_name;
	IF FRODO;
	KEEP horse_name age sr;
RUN;

/* Looking at the data, I see that the sr is - for some races, probably due to disqualification.  Let's remove those. */
DATA work.speedage;
	MERGE work.ppdata1s work.horsedatas (IN=FRODO);
	BY horse_name;
	IF FRODO;
	IF (sr < 0) THEN delete;
	KEEP horse_name age sr;
	LABEL sr = "Speed Rating";
RUN;

/* Let's also find an average sr for each horse, and make sure that the horse's age is consistent throghout the data set by finding an average there, too */
PROC MEANS DATA = work.speedage NOPRINT;
	BY horse_name;
	OUTPUT OUT=work.speedagemean MEAN(sr) = sr MEAN(age) = age;
RUN;

/*########################################################################################################################*/

/* Regression time!  */

PROC REG DATA=work.speedagemean;
	TITLE "The Relationship Between Speed and Age";
	MODEL sr = age;
	PLOT sr * age
		R. * age;
RUN;
QUIT;

/* This isn't a great model, but let's plot with the confidence interval just for good measure. */

GOPTIONS CSYMBOL = BLACK;
SYMBOL1 VALUE = DOT;
SYMBOL2 VALUE = NONE I=RLCLM95;
PROC GPLOT DATA=work.speedagemean;
	TITLE "The Relationship Between Speed and Age With 95% Confidence Interval";
	PLOT sr * age = 1
		sr * age = 2 / OVERLAY;
RUN;
QUIT;

/******************  Now it's time to build a better model. I'm going to model finish time instead ********************/
/**** For each observation, I want to use the finish times from the prior two observations in my model. ****/
/**** I also want to include other variables:  age, condition, gait. ****/
/**** Remove observations where there are disqualifications *****/


DATA work.longitude;
	SET ppdata1;
	_date = input(put(date,8.), YYMMDD8.);
	FORMAT _date MMDDYY10.;
	IF hrse_tm_fn = . THEN delete;
RUN;

PROC SORT DATA=work.longitude;
	BY horse_name _date;
	RUN;
/*##3######################################################################################################################*/
DATA work.laglong;
	SET work.longitude;
	_hrse_tm_fn = hrse_tm_fn*1;
	hrse_tm_fn_lag1 = LAG(hrse_tm_fn)*1;
	hrse_tm_fn_lag2 = LAG2(hrse_tm_fn)*1;
	IF gait in ('P' 'T') THEN pacer = (gait EQ 'P'); /*creates a dummy variable for gait */
	IF cond in ('FT' 'SY' 'GD') THEN DO;
		FT = (cond EQ 'FT');
		SY = (cond EQ 'SY');
	END;		/* Creates two dummy variables based on a categorical variable with 3 categories */
	IF tracksize in ('1/2' '5/8' '1') THEN DO;
		sz58 = (tracksize EQ '5/8');
		sz1 = (tracksize EQ '1');
	END;
	/*I also want condition and track length dummy variables for two races and 1 race prior.  Gait will be the same for all races, so no worries on that! */
	IF lag(cond) in ('FT' 'SY' 'GD') THEN DO;
		FT_lag1 = (lag(cond) EQ 'FT');
		SY_lag1 = (lag(cond) EQ 'SY');
	END;
	IF lag2(cond) in ('FT' 'SY' 'GD') THEN DO;
		FT_lag2 = (lag2(cond) EQ 'FT');
		SY_lag2 = (lag2(cond) EQ 'SY');
	END;
	IF lag(tracksize) in ('1/2' '5/8' '1') THEN DO;
		sz58_lag1 = (lag(tracksize) EQ '5/8');
		sz1_lag1 = (lag(tracksize) EQ '1');
	END;
	IF tracksize in ('1/2' '5/8' '1') THEN DO;
		sz58_lag2 = (lag2(tracksize) EQ '5/8');
		sz1_lag2 = (lag2(tracksize) EQ '1');
	END;
	IF (hrse_tm_fn_lag1 = . OR hrse_tm_fn_lag2 = .) THEN delete; /*This removes the first two observations, which don't have 2 obs worth of history */
RUN;

/* Let's merge in age and gender data */
PROC SORT DATA=work.laglong OUT=work.laglongs;
	BY horse_name;
RUN;

DATA work.laglong;
	MERGE work.laglongs work.horsedatas;
	BY horse_name;
	KEEP horse_name _date _hrse_tm_fn hrse_tm_fn_lag1 hrse_tm_fn_lag2 pacer FT SY FT_lag1 SY_lag1 FT_lag2 SY_lag2 age sz58 sz1 sz58_lag1 sz1_lag1 sz58_lag2 sz1_lag2;
RUN;


/* My data are ready!  Let's run some regressions to find the best-fit model! */

PROC REG DATA=work.laglong OUTEST = work.const;
	TITLE "Regression Model to Explain Final Horse Time";
	MODEL _hrse_tm_fn = hrse_tm_fn_lag1 hrse_tm_fn_lag2 pacer FT SY FT_lag1 SY_lag1 FT_lag2 SY_lag2 age sz58 sz1 sz58_lag1 sz1_lag1 sz58_lag2 sz1_lag2 ;
	RUN;
	QUIT;

/*  Okay, so now I'll use my parameters and the last two records of data for each horse to predict the final time for the horse in the September 26th race, for which this data set was created. */
/*  At this point, the laglongs data is sorted by horse, date.  The last observation for each horse already has that observation's data and the prior observation's data */
/*  So the only variables missing from our model are the final time variable we're predicting (obviously), the condition for the race, the horse's age (in the other data set) and the size of the track */
/*  All of this data come from the program for September 26.  That day the track was FT for all the races.  The track is 1/2 mile. */

DATA work.finalobs;
	MERGE work.laglongs work.horsedatas; /* merging in age variable.  both sets are sorted */
	BY horse_name;
	IF LAST.horse_name;
	hrse_tm_fn_lag2=hrse_tm_fn_lag1; /* just to keep me sane.  the lag1 here is actually lag2 for the September 26 observation */
	hrse_tm_fn_lag1 = hrse_tm_fn;
	FT_lag2 = FT_lag1;
	FT_lag1 = FT;
	FT = 1;
	SY_lag2 = SY_lag1;
	SY_lag1 = SY;
	SY = 0;
	sz58_lag2 = sz58_lag1;
	sz58_lag1 = sz58;
	sz58 = 0;
	sz1_lag2 = sz1_lag1;
	sz1_lag1 = sz1;
	sz1 = 0;
	x = 0; /* dummy variable for merge */
	KEEP horse_name FT SY sz58 sz1 hrse_tm_fn_lag2 hrse_tm_fn_lag1 pacer age FT_lag2 SY_lag2 FT_lag1 SY_lag1 sz58_lag2 sz1_lag2 sz58_lag1 sz1_lag1 racenum92613 x; 
RUN;
/* later I noticed that some of my values are missing */
/* the values missing are for tracksize, which is typically 1/2, so I'm going to replace all missing values with 0 */
PROC STDIZE data=work.finalobs reponly missing=0 out=work.finalobs;
	var _numeric_;
RUN;

/* Let's merge in the parameters.  They're the same for every horse, so we can merge in on a dummy variable called x */
DATA work.constm;
	SET work.const;
	x = 0;
	RENAME hrse_tm_fn_lag1 = hrse_tm_fn_lag1c 
			hrse_tm_fn_lag2 = hrse_tm_fn_lag2c
			pacer = pacerc
			FT = FTc
			SY = SYc
			FT_lag1 = FT_lag1c
			SY_lag1 = SY_lag1c
			FT_lag2 = FT_lag2c
			SY_lag2 = SY_lag2c
			age = agec
			sz58 = sz58c
			sz1 = sz1c
			sz58_lag1 = sz58_lag1c
			sz1_lag1 = sz1_lag1c
			sz58_lag2 = sz58_lag2c
			sz1_lag2 = sz1_lac2c;
RUN;

DATA work.finalpredictions;
	MERGE finalobs work.constm;
	BY x;
	hrse_tm_fn_pdtn=intercept + hrse_tm_fn_lag1*hrse_tm_fn_lag1c + hrse_tm_fn_lag2*hrse_tm_fn_lag2c + pacer * pacerc + FT*FTc + SY * SYc + FT_lag1 * FT_lag1c + SY_lag1 * SY_lag1c + FT_lag2 * FT_lag2c + SY_lag2 * SY_lag2c + age * agec + sz58 * sz58c + sz1 * sz1c + sz58_lag1 * sz58_lag1c + sz1_lag1 * sz1_lag1c + sz58_lag2 * sz58_lag2c + sz1_lag2 * sz1_lac2c;
	KEEP horse_name hrse_tm_fn_pdtn racenum92613;
	LABEL horse_name = "Horse Name" hrse_tm_fn_pdtn = "Predicted Final Time" racenum92613 = "Race Number, Sept. 26, 2013"; 
RUN;

PROC SORT DATA=work.finalpredictions;
	BY racenum92613 hrse_tm_fn_pdtn;
	RUN;

PROC PRINT DATA=work.finalpredictions;
	TITLE "Predictions";
RUN;
/*#############################################################################################################################*/
