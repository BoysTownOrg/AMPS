%AnalyzeAMPSdata.m
%Created 6/11/19 by A. Bosen

%Formatting niceties, to ensure consisency across figures
FONT_SIZE = 24; %point, will be scaled to 50% in Illustrator
FIGURE_WIDTH = 16; %inches, will be scaled to 50% in Illustrator
FIGURE_HEIGHT = 8; %inches, will be scaled to 50% in Illustrator

%As far as I can tell, MATLAB 2020a has a bug in detecting column types without
%explicitly calling detectImportOptions, as we were having trouble reading some of the data correctly.
preOpts = detectImportOptions('AMPS_preDec10_anon.csv');
preData = readtable('AMPS_preDec10_anon.csv',preOpts);
postOpts = detectImportOptions('AMPS_postDec10_anon.csv');
postData = readtable('AMPS_postDec10_anon.csv',postOpts);

%Get the list of indivdiual subjects.  We expect 80, 40 per experiment condition
subjects = unique([preData.Subject;postData.Subject]);
subjects(subjects == 114) = []; %114 could not pass the proficiency check, and should be excluded here.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Load and format pre-test proficiency check data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%wordlistQuiz is the location of the pre-recall test data.
%Loglevel8 seems to be similar words, responses to training in LogLevel7
%LogLevel7 seems to be distinct words, responses to training in LogLevel6
%Peculiar indexing, should talk to Elizabeth about why the data are formatted this way.
%LogLevel7 wordlistQuiz is contaminated with both data from the training and data from the quiz,
%need to do some odd gating of data to only get quiz responses.

%This uses strcmp when there is a single unique column, and the cellfun regexp format when searching for multiple columns
preProficiencyCheckColumnIndex = strcmp('Subject',preData.Properties.VariableNames) | ... %Subject ID
				strcmp(preData.Properties.VariableNames,'wordListType_SubTrial_') | ... %experiment condition
				~cellfun('isempty',regexp(preData.Properties.VariableNames,'Procedure.LogLevel[67]','match')) | ... %Procedure, filters proficiency trials
				~cellfun('isempty',regexp(preData.Properties.VariableNames,'wordlist.LogLevel[67]','match')) | ... %Target 
				~cellfun('isempty',regexp(preData.Properties.VariableNames,'wordlistQuiz.RESP.LogLevel[78]','match')) | ... %Response
				~cellfun('isempty',regexp(preData.Properties.VariableNames,'wordlistQuiz.RT.LogLevel[78]','match')); %RT
postProficiencyCheckColumnIndex = strcmp('Subject',postData.Properties.VariableNames) | ... %Subject ID
				strcmp(postData.Properties.VariableNames,'wordListType_SubTrial_') | ... %experiment condition
				~cellfun('isempty',regexp(postData.Properties.VariableNames,'Procedure.LogLevel[67]','match')) | ... %Procedure, filters proficiency trials
				~cellfun('isempty',regexp(postData.Properties.VariableNames,'wordlist.LogLevel[67]','match')) | ... %Target 
				~cellfun('isempty',regexp(postData.Properties.VariableNames,'wordlistQuiz.RESP.LogLevel[78]','match')) | ... %Response
				~cellfun('isempty',regexp(postData.Properties.VariableNames,'wordlistQuiz.RT.LogLevel[78]','match')); %RT

%Combine data from the two spreadsheets
rawProfCheckData = [preData(:,preProficiencyCheckColumnIndex); postData(:,postProficiencyCheckColumnIndex)]; 
%Remove non-data rows from the table
trimmedProfCheckData = rawProfCheckData(strcmp(rawProfCheckData.Procedure_LogLevel6_,'profCheckProc') |...
						strcmp(rawProfCheckData.Procedure_LogLevel7_,'profCheckProc'),:);
trimmedProfCheckData = trimmedProfCheckData(~(strcmp(trimmedProfCheckData.wordlistQuiz_RESP_LogLevel7_,'') &...
						strcmp(trimmedProfCheckData.wordlistQuiz_RESP_LogLevel8_,'')),:);
%Format the resulting data to be easy to read in its final form
%Start with just the subject number and condition
profCheckData = trimmedProfCheckData(:,1:2);
profCheckData.Properties.VariableNames{2} = 'Condition';
%Group is a shortcut for indexing by which similar condition each subject did, rather than having to calculate it
%every time we want to split the ADW data by group.
profCheckData.Group = repmat({''},height(profCheckData),1);
for(subjectIndex = 1:length(subjects))
	if(any(strcmp(profCheckData.Condition(profCheckData.Subject == subjects(subjectIndex)),'PoMR')))
		profCheckData.Group(profCheckData.Subject == subjects(subjectIndex)) = repmat({'PoMR'},sum(profCheckData.Subject == subjects(subjectIndex)),1);
	elseif(any(strcmp(profCheckData.Condition(profCheckData.Subject == subjects(subjectIndex)),'PdMR')))
		profCheckData.Group(profCheckData.Subject == subjects(subjectIndex)) = repmat({'PdMR'},sum(profCheckData.Subject == subjects(subjectIndex)),1);
	end
end
%Add the target word, which is always in LogLevel7 for some reason
profCheckData.Target = trimmedProfCheckData.wordlist_LogLevel7_;
%Combine responses from both task types
profCheckData.Response = strcat(trimmedProfCheckData.wordlistQuiz_RESP_LogLevel7_, trimmedProfCheckData.wordlistQuiz_RESP_LogLevel8_);
%Format the responses to match the string format of the targets
profCheckData.Response = lower(strrep(strrep(profCheckData.Response,'{',''),'}',''));
%Determine if the response was correct
profCheckData.Correct = strcmp(profCheckData.Target,profCheckData.Response);
%Convert RTs from strings to numbers
profCheckData.RT = strcat(trimmedProfCheckData.wordlistQuiz_RT_LogLevel7_, trimmedProfCheckData.wordlistQuiz_RT_LogLevel8_);
profCheckData.RT = strrep(profCheckData.RT,'NA','');
profCheckData.RT = cellfun(@(x) str2num(char(x)),profCheckData.RT);

%Define the lists of words used in each condition
ADWWordList = unique(profCheckData.Target(strcmp(profCheckData.Condition,'ADW')));
PoMRWordList = unique(profCheckData.Target(strcmp(profCheckData.Condition,'PoMR')));
PdMRWordList = unique(profCheckData.Target(strcmp(profCheckData.Condition,'PdMR')));
%unique sorts words, which we want to avoid, so we use this indexing to ensure
%the PoMR and PdMR words are aligned.
correctPdMROrder = [1 2 4 3 5 6 7 10 9 8]; 
PdMRWordList = PdMRWordList(correctPdMROrder);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Load and format post-test proficiency check data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%wordlistQuiz1 is the location of the post-recall proficiency check data.
%This was added to the postDec10 data, so it is not present in the preDec10 data.

postRecallProficiencyCheckColumnIndex = strcmp('Subject',postData.Properties.VariableNames) | ... %Subject ID
					strcmp('wordListType_SubTrial_',postData.Properties.VariableNames) | ... %experiment condition
					strcmp('wordlist_Trial_',postData.Properties.VariableNames) | ... %Target 
					strcmp('wordlistQuiz1_RESP',postData.Properties.VariableNames) | ... %Response
					strcmp('wordlistQuiz1_RT',postData.Properties.VariableNames);  ... %RT

%Combine data from the two spreadsheets
rawPostRecallProfCheckData = postData(:,postRecallProficiencyCheckColumnIndex); 
%Remove non-data rows from the table
postRecallProfCheckData = rawPostRecallProfCheckData(~strcmp(rawPostRecallProfCheckData.wordlistQuiz1_RESP,''),:);
postRecallProfCheckData.Properties.VariableNames = {'Subject', 'Target', 'Response', 'RT', 'Group'};

%Format the responses to match the string format of the targets
postRecallProfCheckData.Response = lower(strrep(strrep(postRecallProfCheckData.Response,'{',''),'}',''));
%Determine if the response was correct
postRecallProfCheckData.Correct = strcmp(postRecallProfCheckData.Target,postRecallProfCheckData.Response);
%Convert RTs from strings to numbers
postRecallProfCheckData.RT = cellfun(@(x) str2num(char(x)),postRecallProfCheckData.RT);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Load and format serial recall data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%ADW are stored in Loglevel6, PoMR and PdMR are stored in LogLevel7.
preSerialRecallColumnIndex = strcmp('Subject',preData.Properties.VariableNames) | ... %Subject ID
			strcmp(preData.Properties.VariableNames,'wordListType_SubTrial_') | ... %experiment condition
			~cellfun('isempty',regexp(preData.Properties.VariableNames,'sf[1-6]_LogLevel[67]_','match')) | ... %Targets
			~cellfun('isempty',regexp(preData.Properties.VariableNames,'trials[1-6]_RESP_LogLevel[67]_','match')) | ... %Responses
			~cellfun('isempty',regexp(preData.Properties.VariableNames,'trials[1-6]_RT_LogLevel[67]_','match')); %RTs
postSerialRecallColumnIndex = strcmp('Subject',postData.Properties.VariableNames) | ... %Subject ID
			strcmp(postData.Properties.VariableNames,'wordListType_SubTrial_') | ... %experiment condition
			~cellfun('isempty',regexp(postData.Properties.VariableNames,'sf[1-6]_LogLevel[67]_','match')) | ... %Targets
			~cellfun('isempty',regexp(postData.Properties.VariableNames,'trials[1-6]_RESP_LogLevel[67]_','match')) | ... %Responses
			~cellfun('isempty',regexp(postData.Properties.VariableNames,'trials[1-6]_RT_LogLevel[67]_','match')); %RTs

%Combine data from the two spreadsheets
rawSerialRecallData = [preData(:,preSerialRecallColumnIndex); postData(:,postSerialRecallColumnIndex)];

%For responses and RTs, we need to shift all the data up a single row, so they align with the corresponding presentations
responseAndRTColumns = ~cellfun('isempty',regexp(rawSerialRecallData.Properties.VariableNames,'trials[1-6]_(RT)|(RESP)_LogLevel[67]_','match'));
rawSerialRecallData(1:end-1,responseAndRTColumns) = rawSerialRecallData(2:end,responseAndRTColumns);
%Remove non-response rows from the table
responseColumns = ~cellfun('isempty',regexp(rawSerialRecallData.Properties.VariableNames,'trials[1-6]_RESP_LogLevel[67]_','match'));
trimmedSerialRecallData = rawSerialRecallData(~all(strcmp(rawSerialRecallData{:,responseColumns},''),2),:);
%Format the table to be easy to read
serialRecallData = trimmedSerialRecallData(:,1:2);
serialRecallData.Properties.VariableNames{2} = 'Condition';
serialRecallData.Group = repmat({''},height(serialRecallData),1);
for(subjectIndex = 1:length(subjects))
	if(any(strcmp(serialRecallData.Condition(serialRecallData.Subject == subjects(subjectIndex)),'PoMR')))
		serialRecallData.Group(serialRecallData.Subject == subjects(subjectIndex)) = repmat({'PoMR'},sum(serialRecallData.Subject == subjects(subjectIndex)),1);
	elseif(any(strcmp(serialRecallData.Condition(serialRecallData.Subject == subjects(subjectIndex)),'PdMR')))
		serialRecallData.Group(serialRecallData.Subject == subjects(subjectIndex)) = repmat({'PdMR'},sum(serialRecallData.Subject == subjects(subjectIndex)),1);
	end
end

serialRecallData.Target1 = strcat(trimmedSerialRecallData.sf1_LogLevel6_,trimmedSerialRecallData.sf1_LogLevel7_);
serialRecallData.Target2 = strcat(trimmedSerialRecallData.sf2_LogLevel6_,trimmedSerialRecallData.sf2_LogLevel7_);
serialRecallData.Target3 = strcat(trimmedSerialRecallData.sf3_LogLevel6_,trimmedSerialRecallData.sf3_LogLevel7_);
serialRecallData.Target4 = strcat(trimmedSerialRecallData.sf4_LogLevel6_,trimmedSerialRecallData.sf4_LogLevel7_);
serialRecallData.Target5 = strcat(trimmedSerialRecallData.sf5_LogLevel6_,trimmedSerialRecallData.sf5_LogLevel7_);
serialRecallData.Target6 = strcat(trimmedSerialRecallData.sf6_LogLevel6_,trimmedSerialRecallData.sf6_LogLevel7_);
%Remove the .wav suffix from the stimulus file names
targetColumnIndex = 4:9;
serialRecallData(:,targetColumnIndex) = strrep(serialRecallData{:,targetColumnIndex},'.wav','');
%For PdMR, we need to convert file names to the given lexical labels
PdMRTrialIndex = strcmp(serialRecallData.Condition,'PdMR');
serialRecallData(PdMRTrialIndex,targetColumnIndex) = strrep(serialRecallData{PdMRTrialIndex,targetColumnIndex},'ran','roam');
serialRecallData(PdMRTrialIndex,targetColumnIndex) = strrep(serialRecallData{PdMRTrialIndex,targetColumnIndex},'pan','pain');
serialRecallData(PdMRTrialIndex,targetColumnIndex) = strrep(serialRecallData{PdMRTrialIndex,targetColumnIndex},'bag','beg');
serialRecallData(PdMRTrialIndex,targetColumnIndex) = strrep(serialRecallData{PdMRTrialIndex,targetColumnIndex},'man','noun');
serialRecallData(PdMRTrialIndex,targetColumnIndex) = strrep(serialRecallData{PdMRTrialIndex,targetColumnIndex},'rat','wet');
serialRecallData(PdMRTrialIndex,targetColumnIndex) = strrep(serialRecallData{PdMRTrialIndex,targetColumnIndex},'bat','but');
serialRecallData(PdMRTrialIndex,targetColumnIndex) = strrep(serialRecallData{PdMRTrialIndex,targetColumnIndex},'pat','pot');
serialRecallData(PdMRTrialIndex,targetColumnIndex) = strrep(serialRecallData{PdMRTrialIndex,targetColumnIndex},'tan','tune');
serialRecallData(PdMRTrialIndex,targetColumnIndex) = strrep(serialRecallData{PdMRTrialIndex,targetColumnIndex},'tap','talk');
serialRecallData(PdMRTrialIndex,targetColumnIndex) = strrep(serialRecallData{PdMRTrialIndex,targetColumnIndex},'mat','knit');

serialRecallData.Response1 = strcat(trimmedSerialRecallData.trials1_RESP_LogLevel6_,trimmedSerialRecallData.trials1_RESP_LogLevel7_);
serialRecallData.Response2 = strcat(trimmedSerialRecallData.trials2_RESP_LogLevel6_,trimmedSerialRecallData.trials2_RESP_LogLevel7_);
serialRecallData.Response3 = strcat(trimmedSerialRecallData.trials3_RESP_LogLevel6_,trimmedSerialRecallData.trials3_RESP_LogLevel7_);
serialRecallData.Response4 = strcat(trimmedSerialRecallData.trials4_RESP_LogLevel6_,trimmedSerialRecallData.trials4_RESP_LogLevel7_);
serialRecallData.Response5 = strcat(trimmedSerialRecallData.trials5_RESP_LogLevel6_,trimmedSerialRecallData.trials5_RESP_LogLevel7_);
serialRecallData.Response6 = strcat(trimmedSerialRecallData.trials6_RESP_LogLevel6_,trimmedSerialRecallData.trials6_RESP_LogLevel7_);
%Format the responses to match the string format of the targets
responseColumnIndex = 10:15;
serialRecallData(:,responseColumnIndex) = lower(strrep(strrep(serialRecallData{:,responseColumnIndex},'{',''),'}',''));

%Determine if the responses were correct
correctColumnIndex = 16:21;
serialRecallData{:,correctColumnIndex} = strcmp(serialRecallData{:,targetColumnIndex},serialRecallData{:,responseColumnIndex});
serialRecallData.Properties.VariableNames(correctColumnIndex) = cellstr(strcat('Correct',  num2str(1:6,'%1d')'));

serialRecallData.RT1 = strcat(trimmedSerialRecallData.trials1_RT_LogLevel6_,trimmedSerialRecallData.trials1_RT_LogLevel7_);
serialRecallData.RT2 = strcat(trimmedSerialRecallData.trials2_RT_LogLevel6_,trimmedSerialRecallData.trials2_RT_LogLevel7_);
serialRecallData.RT3 = strcat(trimmedSerialRecallData.trials3_RT_LogLevel6_,trimmedSerialRecallData.trials3_RT_LogLevel7_);
serialRecallData.RT4 = strcat(trimmedSerialRecallData.trials4_RT_LogLevel6_,trimmedSerialRecallData.trials4_RT_LogLevel7_);
serialRecallData.RT5 = strcat(trimmedSerialRecallData.trials5_RT_LogLevel6_,trimmedSerialRecallData.trials5_RT_LogLevel7_);
serialRecallData.RT6 = strcat(trimmedSerialRecallData.trials6_RT_LogLevel6_,trimmedSerialRecallData.trials6_RT_LogLevel7_);
%Convert RTs from strings to numbers
RTColumnIndex = 22:27;
serialRecallData(:,RTColumnIndex) = strrep(serialRecallData{:,RTColumnIndex},'NA','');
%I can't figure out the syntax to do this assignment all at once,
%so the below is a hack to get the RT data into numerics
RTmatrix = cellfun(@(x) str2num(char(x)),serialRecallData{:,RTColumnIndex});
serialRecallData.RT1 = RTmatrix(:,1);
serialRecallData.RT2 = RTmatrix(:,2);
serialRecallData.RT3 = RTmatrix(:,3);
serialRecallData.RT4 = RTmatrix(:,4);
serialRecallData.RT5 = RTmatrix(:,5);
serialRecallData.RT6 = RTmatrix(:,6);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Load and format musical sophistication index data
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Responses are gmsiPresent1.Choice1.Value, question numbers are gmsiList1
preMSIColumnIndex = strcmp('Subject',preData.Properties.VariableNames) | ... %Subject ID
			strcmp(preData.Properties.VariableNames,'gmsiList1') | ... %Question numbers
			strcmp(preData.Properties.VariableNames,'gmsiPresent1_Choice1_Value') | ... %Responses
			strcmp(preData.Properties.VariableNames,'gmsiPresent2_Choice1_Value') | ... %Responses to question 16
			strcmp(preData.Properties.VariableNames,'gmsiPresent3_Choice1_Value') | ... %Responses to question 17
			strcmp(preData.Properties.VariableNames,'gmsiPresent4_Choice1_Value'); %Responses to question 18
%Column names changed for the post data set for some reason.
postMSIColumnIndex = strcmp('Subject',postData.Properties.VariableNames) | ... %Subject ID
			strcmp(postData.Properties.VariableNames,'gmsiList1_Block_') | ... %Question numbers
			strcmp(postData.Properties.VariableNames,'gmsiPresent1_Choice1_Value_Block_') |... %Responses
			strcmp(postData.Properties.VariableNames,'gmsiPresent2_Choice1_Value_Block_') |... %Responses to question 16
			strcmp(postData.Properties.VariableNames,'gmsiPresent3_Choice1_Value_Block_') |... %Responses to question 17
			strcmp(postData.Properties.VariableNames,'gmsiPresent4_Choice1_Value_Block_'); %Responses to question 18

postMSIData = postData(:,postMSIColumnIndex);
postMSIData.Properties.VariableNames = preData.Properties.VariableNames(preMSIColumnIndex);

%Combine data from the two spreadsheets
rawMSIData = [preData(:,preMSIColumnIndex); postMSIData];

%Note that 1-15 are stored in item number - response format, whereas 16-18 are separate columns
trimmedMSIData = rawMSIData(~all(strcmp(rawMSIData{:,2:3},'NA'),2) | ~strcmp(rawMSIData{:,4},'NA'),:);

MSISummary = table(subjects,nan(numel(subjects),1),nan(numel(subjects),1),nan(numel(subjects),1),nan(numel(subjects),1),'VariableNames',{'Subject','Score','DistinctPerformance','PoMRPerformance','PdMRPerformance'});

for(subjectIndex = 1:height(MSISummary))
	currentSubject = MSISummary.Subject(subjectIndex);
	currentSubjectData = trimmedMSIData(trimmedMSIData.Subject == currentSubject,:);
	if(any(strcmp(currentSubjectData.gmsiPresent1_Choice1_Value(1:15),'NA')))
		%This is a catch for the one missing data point for one participant.
	else
		first15Responses = cellfun(@(x) str2num(char(x)),currentSubjectData.gmsiPresent1_Choice1_Value(1:15));

		%These questions are on a reversed scale, so lower numbers indicate higher sophstication
		FLIPPED_QUESTIONS = [7 9 11 13 14];
		first15Responses(FLIPPED_QUESTIONS) = 8 - first15Responses(FLIPPED_QUESTIONS);
		question16Response = str2num(currentSubjectData.gmsiPresent2_Choice1_Value{16});
		question17Response = str2num(currentSubjectData.gmsiPresent3_Choice1_Value{16});
		question18Response = str2num(currentSubjectData.gmsiPresent4_Choice1_Value{16});

		MSISummary.Score(subjectIndex) = sum([first15Responses; question16Response; question17Response; question18Response]);
	end
end


disp('********************************************************************************');
disp(['Gold-MSI Statistics: mean = ' num2str(mean(MSISummary.Score,'omitnan')) ', SD = ' num2str(std(MSISummary.Score,'omitnan'))]);
disp(['Gold-MSI Statistics: max = ' num2str(max(MSISummary.Score)) ', min = ' num2str(min(MSISummary.Score))]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Figure 2, correct item rates across all four conditions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure;
hold on;
PoMRGroupADWMeans = [];
PoMRMeans = [];
PdMRGroupADWMeans = [];
PdMRMeans = [];
for(subjectIndex = 1:length(subjects))
	currentSubject = subjects(subjectIndex);
	currentSubjectData = serialRecallData(serialRecallData.Subject == currentSubject,:);
	if(any(strcmp(currentSubjectData.Condition,'PoMR')))
		%This subject was in the veridical group
		currentSubjectDistinctData = currentSubjectData(strcmp(currentSubjectData.Condition,'ADW'),:);
		currentSubjectDistinctPerformance = mean(mean(currentSubjectDistinctData{:,correctColumnIndex}));
		currentSubjectSimilarData = currentSubjectData(strcmp(currentSubjectData.Condition,'PoMR'),:);
		currentSubjectSimilarPerformance = mean(mean(currentSubjectSimilarData{:,correctColumnIndex}));
		
		plot([1 2],[currentSubjectDistinctPerformance currentSubjectSimilarPerformance],'o-','Color',[0.3 0.3 0.3],'Linewidth',2);
		PoMRGroupADWMeans = [PoMRGroupADWMeans currentSubjectDistinctPerformance];
		PoMRMeans = [PoMRMeans currentSubjectSimilarPerformance];

		%Add these data to the MSI table for later analysis
		MSISummary.PoMRPerformance(subjectIndex) = currentSubjectSimilarPerformance;
	elseif(any(strcmp(currentSubjectData.Condition,'PdMR')))
		%This subject was in the spurious group
		currentSubjectDistinctData = currentSubjectData(strcmp(currentSubjectData.Condition,'ADW'),:);
		currentSubjectDistinctPerformance = mean(mean(currentSubjectDistinctData{:,correctColumnIndex}));
		currentSubjectSimilarData = currentSubjectData(strcmp(currentSubjectData.Condition,'PdMR'),:);
		currentSubjectSimilarPerformance = mean(mean(currentSubjectSimilarData{:,correctColumnIndex}));
		
		plot([2.75 3.75],[currentSubjectDistinctPerformance currentSubjectSimilarPerformance],'o-','Color',[0.6 0.6 0.6],'Linewidth',2);
		PdMRGroupADWMeans = [PdMRGroupADWMeans currentSubjectDistinctPerformance];
		PdMRMeans = [PdMRMeans currentSubjectSimilarPerformance];

		%Add these data to the MSI table for later analysis
		MSISummary.PdMRPerformance(subjectIndex) = currentSubjectSimilarPerformance;
	end

	%Add these data to the MSI table for later analysis
	MSISummary.DistinctPerformance(subjectIndex) = currentSubjectDistinctPerformance;

end
plot([1 2],[mean(PoMRGroupADWMeans) mean(PoMRMeans)],'k-','Linewidth',10);
plot([2.75 3.75],[mean(PdMRGroupADWMeans) mean(PdMRMeans)],'-','Linewidth',10,'Color',[0.4 0.4 0.4]);
axis([0.7 4.05 0 1]);
xticks([1 2 2.75 3.75]);
xticklabels({'Distinct Words',' Similar Words\newlineMatched Labels','Distinct Words','    Similar Words\newlineMismatched Labels'});
ylabel('Proportion Correct Responses');
box on;
set(gca,'FontSize',FONT_SIZE);
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 FIGURE_WIDTH FIGURE_HEIGHT]);
outputFileName = ['.\Figures\Cross Condition Recall Accuracy'];
print(outputFileName,'-dpng','-r600');

disp('********************************************************************************');
disp(['PoMR Group ADW Proportion Correct Group mean: ' num2str(mean(PoMRGroupADWMeans)) ', std: ' num2str(std(PoMRGroupADWMeans))]);
disp(['PdMR Group ADW Proportion Correct Group mean: ' num2str(mean(PdMRGroupADWMeans)) ', std: ' num2str(std(PdMRGroupADWMeans))]);
[~,PSEP,PSECI,PSEStats] = ttest(PoMRGroupADWMeans,PoMRMeans);
disp(['PSE P-Value: ' num2str(PSEP)]);
[~,ADWComparisonP,ADWComparisonCI,ADWComparisonStats] = ttest2(PoMRGroupADWMeans,PdMRGroupADWMeans);
disp(['ADW Comparison P-Value: ' num2str(ADWComparisonP)]);

disp(['PoMR Proportion Correct Group mean: ' num2str(mean(PoMRMeans)), ', std: ' num2str(std(PoMRMeans))]);
disp(['PdMR Proportion Correct Group mean: ' num2str(mean(PdMRMeans)), ', std: ' num2str(std(PdMRMeans))]);
[~,SimilarComparisonP,SimilarComparisonCI,SimilarComparisonStats] = ttest2(PoMRMeans,PdMRMeans);
disp(['Similar Comparison P-Value: ' num2str(SimilarComparisonP)]);

%Three participants went in the wrong direction for the distinct word to similar word, matched label condition:
%Removing those participants puts the p value right on the edge of significance, but further analysis below
%indicates that the difference is real.
outlierIndex = MSISummary.DistinctPerformance - MSISummary.PoMRPerformance < 0;
outlierSubjectNumbers = MSISummary.Subject(outlierIndex);
[~,SimilarComparisonWithoutOutlierP,SimilarComparisonWithoutOutlierCI,SimilarComparisonWithoutOutlierStats] =...
       	ttest2(MSISummary.PoMRPerformance(~outlierIndex & ~isnan(MSISummary.PoMRPerformance)),PdMRMeans);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Figure 3, number of pre-recall proficiency checks required to pass
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
PoMRGroupADWProfCheckCount = nan(1,length(subjects));
PdMRGroupADWProfCheckCount = nan(1,length(subjects));
PoMRProfCheckCount = nan(1,length(subjects));
PdMRProfCheckCount = nan(1,length(subjects));
for(subjectIndex = 1:length(subjects))
	currentSubjectData = profCheckData(profCheckData.Subject == subjects(subjectIndex),:);
	%The /10 here is because each proficiency check was 10 trials.
	if(any(strcmp(currentSubjectData.Group,'PoMR')))
		PoMRGroupADWProfCheckCount(subjectIndex) = sum((strcmp(currentSubjectData.Condition,'ADW')))/10;
		PoMRProfCheckCount(subjectIndex) = sum((strcmp(currentSubjectData.Condition,'PoMR')))/10;
	elseif(any(strcmp(currentSubjectData.Group,'PdMR')))
		PdMRGroupADWProfCheckCount(subjectIndex) = sum((strcmp(currentSubjectData.Condition,'ADW')))/10;
		PdMRProfCheckCount(subjectIndex) = sum((strcmp(currentSubjectData.Condition,'PdMR')))/10;
	end
end

%We removed subject 114 earlier, so we want to put them back for this figure.
%They failed 10 times before we stopped the test.
PdMRProfCheckCount = [PdMRProfCheckCount 10];

figure;
histogram(PoMRGroupADWProfCheckCount,'Binwidth',1,'BinLimits',[0.5 10.5],'FaceAlpha',1,'FaceColor','k');
hold on;
histogram(PdMRGroupADWProfCheckCount,'Binwidth',1,'BinLimits',[0.5 10.5],'FaceAlpha',0.7,'FaceColor',[0.6 0.6 0.6]);
ylabel('Number of Participants');
xlabel('Proficiency Checks');
xticks(1:10);
yticks(0:5:35);
axis([0.25 10.75 0 39]);
set(gca,'FontSize',FONT_SIZE);
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 FIGURE_WIDTH/2 FIGURE_HEIGHT-2]);
outputFileName = ['.\Figures\Proficiency Check Count for Distinct Lists'];
print(outputFileName,'-dpng','-r600');

figure;
histogram(PoMRProfCheckCount,'Binwidth',1,'BinLimits',[0.5 10.5],'FaceAlpha',1,'FaceColor','k');
hold on;
histogram(PdMRProfCheckCount,'Binwidth',1,'BinLimits',[0.5 10.5],'FaceAlpha',0.7,'FaceColor',[0.6 0.6 0.6]);
ylabel('Number of Participants');
xlabel('Proficiency Checks');
xticks(1:10);
yticks(0:5:35);
axis([0.25 10.75 0 39]);
set(gca,'FontSize',FONT_SIZE);
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 FIGURE_WIDTH/2 FIGURE_HEIGHT-2]);
outputFileName = ['.\Figures\Proficiency Check Count for Similar Lists'];
print(outputFileName,'-dpng','-r600');

[ProfCheckP, ~, ProfCheckStats] = ranksum(PoMRProfCheckCount(~isnan(PoMRProfCheckCount)),PdMRProfCheckCount(~isnan(PdMRProfCheckCount)),'method','exact')

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Post-recall proficiency check accuracy test across groups
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
postRecallProfCheckCorrectPoMRTrials = sum(postRecallProfCheckData.Correct(strcmp('PoMR',postRecallProfCheckData.Group)));
postRecallProfCheckTotalPoMRTrials = sum(strcmp('PoMR',postRecallProfCheckData.Group));
postRecallProfCheckIncorrectPoMRTrials = postRecallProfCheckTotalPoMRTrials - postRecallProfCheckCorrectPoMRTrials;
postRecallProfCheckCorrectPdMRTrials = sum(postRecallProfCheckData.Correct(strcmp('PdMR',postRecallProfCheckData.Group)));
postRecallProfCheckTotalPdMRTrials = sum(strcmp('PdMR',postRecallProfCheckData.Group));
postRecallProfCheckIncorrectPdMRTrials = postRecallProfCheckTotalPdMRTrials - postRecallProfCheckCorrectPdMRTrials;

disp('Post-recall proficiency checks accuracy:');
disp(['   PoMR: ' num2str(postRecallProfCheckCorrectPoMRTrials/postRecallProfCheckTotalPoMRTrials)]);
disp(['   PdMR: ' num2str(postRecallProfCheckCorrectPdMRTrials/postRecallProfCheckTotalPdMRTrials)]);
[~,postRecallAccuracyFisherP] =  fishertest([postRecallProfCheckCorrectPoMRTrials, postRecallProfCheckIncorrectPoMRTrials;...
						postRecallProfCheckCorrectPdMRTrials, postRecallProfCheckIncorrectPdMRTrials]);
disp(['   Fisher Exact test P: ' num2str(postRecallAccuracyFisherP)]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Figure 4, RTs for proficiency checks across conditions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Get just the final 10 RTs from each proficiency check, since those are the 10
%that they got 100% correct.
correctSetProfCheckData = [];
for(subjectIndex = 1:length(subjects))
	currentSubjectData = profCheckData(profCheckData.Subject == subjects(subjectIndex),:);
	subjectConditions = unique(currentSubjectData.Condition);
	for(conditionIndex = 1:length(subjectConditions))
		currentConditionData = currentSubjectData(strcmp(subjectConditions{conditionIndex},currentSubjectData.Condition),:);
		%Append only the last 10 trials
		if(isempty(correctSetProfCheckData))
			correctSetProfCheckData = currentConditionData(end-9:end,:);
		else
			correctSetProfCheckData = [correctSetProfCheckData;currentConditionData(end-9:end,:)];
		end
	end
end
assert(all(correctSetProfCheckData.Correct),'Accidentally included an incorrect trial in correct set proficiency check data');

figure;
hold on;
for(ADWWordIndex = 1:length(ADWWordList))
	PoMRGroupCurrentWordRTs = correctSetProfCheckData.RT(strcmp(correctSetProfCheckData.Group,'PoMR') & strcmp(correctSetProfCheckData.Target,ADWWordList{ADWWordIndex}));
	[PoMRGroupCurrentWordRTs PoMRGroupOutlierRTs] = SplitRTOutliers(PoMRGroupCurrentWordRTs);
	nPoMRGroupCurrentWordOutliers(ADWWordIndex) = numel(PoMRGroupOutlierRTs);
	plot(repmat(ADWWordIndex-0.2,1,length(PoMRGroupCurrentWordRTs)),PoMRGroupCurrentWordRTs,'.k','MarkerSize',20);
	plot(ADWWordIndex + [-0.4 0],repmat(geomean(PoMRGroupCurrentWordRTs),1,2),'-k','LineWidth',5);

	PdMRGroupCurrentWordRTs = correctSetProfCheckData.RT(strcmp(correctSetProfCheckData.Group,'PdMR') & strcmp(correctSetProfCheckData.Target,ADWWordList{ADWWordIndex}));
	[PdMRGroupCurrentWordRTs PdMRGroupOutlierRTs] = SplitRTOutliers(PdMRGroupCurrentWordRTs);
	nPdMRGroupCurrentWordOutliers(ADWWordIndex) = numel(PdMRGroupOutlierRTs);
	plot(repmat(ADWWordIndex+0.2,1,length(PdMRGroupCurrentWordRTs)),PdMRGroupCurrentWordRTs,'.','Color',[0.6 0.6 0.6],'MarkerSize',20);
	plot(ADWWordIndex + [0 0.4],repmat(geomean(PdMRGroupCurrentWordRTs),1,2),'-','Color',[0.6 0.6 0.6],'LineWidth',5);
	distinctWordRTRankSumPValue(ADWWordIndex) = ranksum(PoMRGroupCurrentWordRTs,PdMRGroupCurrentWordRTs);
end
xticks(1:length(ADWWordList));
xticklabels(strcat(ADWWordList, '\newline ',ADWWordList)); %The newline ensures that both figures are the same size
axis([0.5 10.5 0 4300]);
ylabel('Response Time (ms)');
set(gca,'FontSize',FONT_SIZE);
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 FIGURE_WIDTH FIGURE_HEIGHT-2]);
outputFileName = ['.\Figures\Proficiency Check RTs for Distinct Words'];
print(outputFileName,'-dpng','-r600');

disp('********************************************************************************');
disp('Proficiency Check RT Differences For Distinct Words')
disp(num2str(distinctWordRTRankSumPValue));
disp(['Significant values are < ' num2str(0.05/10) ' after Bonferroni correction']);


figure;
hold on;
for(PoMRWordIndex = 1:length(PoMRWordList))
	PoMRCurrentWordRTs = correctSetProfCheckData.RT(strcmp(correctSetProfCheckData.Target,PoMRWordList{PoMRWordIndex}));
	[PoMRCurrentWordRTs PoMROutlierRTs] = SplitRTOutliers(PoMRCurrentWordRTs);
	nCurrentWordPoMROutliers(PoMRWordIndex) = numel(PoMROutlierRTs);
	plot(repmat(PoMRWordIndex-0.2,1,length(PoMRCurrentWordRTs)),PoMRCurrentWordRTs,'.k','MarkerSize',20);
	plot(PoMRWordIndex + [-0.4 0],repmat(geomean(PoMRCurrentWordRTs),1,2),'-k','LineWidth',5);

	PdMRCurrentWordRTs = correctSetProfCheckData.RT(strcmp(correctSetProfCheckData.Target,PdMRWordList{PoMRWordIndex}));
	[PdMRCurrentWordRTs PdMROutlierRTs] = SplitRTOutliers(PdMRCurrentWordRTs);
	nCurrentWordPdMROutliers(PoMRWordIndex) = numel(PdMROutlierRTs);
	plot(repmat(PoMRWordIndex+0.2,1,length(PdMRCurrentWordRTs)),PdMRCurrentWordRTs,'.','Color',[0.6 0.6 0.6],'MarkerSize',20);
	plot(PoMRWordIndex + [0 0.4],repmat(geomean(PdMRCurrentWordRTs),1,2),'-','Color',[0.6 0.6 0.6],'LineWidth',5);
	similarWordRTRankSumPValue(PoMRWordIndex) = ranksum(PoMRCurrentWordRTs,PdMRCurrentWordRTs);
end
xticks(1:length(PoMRWordList));
xticklabels(strcat(PoMRWordList,'\newline',PdMRWordList));
axis([0.5 10.5 0 4300]);
ylabel('Response Time (ms)');
set(gca,'FontSize',FONT_SIZE);
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 FIGURE_WIDTH FIGURE_HEIGHT-2]);
outputFileName = ['.\Figures\Proficiency Check RTs for Similar Words'];
print(outputFileName,'-dpng','-r600');

disp('********************************************************************************');
disp('Proficiency Check RT Differences For Similar Words')
disp(num2str(similarWordRTRankSumPValue));
disp(['Significant values are < ' num2str(0.05/10) ' after Bonferroni correction']);

%Cross list prof check RT difference, aggregated across words
distinctWordProfCheckRTs = correctSetProfCheckData.RT(strcmp(correctSetProfCheckData.Condition,'ADW'));
similarWordProfCheckRTs = [correctSetProfCheckData.RT(strcmp(correctSetProfCheckData.Condition,'PoMR'));
				correctSetProfCheckData.RT(strcmp(correctSetProfCheckData.Condition,'PdMR'))];
crossListProfCheckRTP = ranksum(distinctWordProfCheckRTs,similarWordProfCheckRTs);
disp(['Proficiency check RT differences across word lists, p = ' num2str(crossListProfCheckRTP)]);
disp(['Proficiency check RT differences across word lists, mean = ' num2str(geomean(similarWordProfCheckRTs) - geomean(distinctWordProfCheckRTs))]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Figure 4 Supplement, with outliers included
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

figure;
hold on;
%We loop through the ADW words twice, once for the PoMR group and once for the PdMR group
for(ADWWordIndex = 1:length(ADWWordList))
	currentWordRTs = correctSetProfCheckData.RT(strcmp(correctSetProfCheckData.Group,'PoMR') &...
       							strcmp(correctSetProfCheckData.Target,ADWWordList{ADWWordIndex}));
	[currentWordRTs outlierRTs] = SplitRTOutliers(currentWordRTs);
	plot(repmat(ADWWordIndex-0.2,1,length(currentWordRTs)),currentWordRTs,'.k','MarkerSize',20);
	plot(repmat(ADWWordIndex-0.2,1,length(outlierRTs)),outlierRTs,'.r','MarkerSize',20);
	plot(ADWWordIndex + [-0.4 0],repmat(geomean([currentWordRTs;outlierRTs]),1,2),'-r','LineWidth',5);
	plot(ADWWordIndex + [-0.4 0],repmat(geomean(currentWordRTs),1,2),'-k','LineWidth',5);
end
for(ADWWordIndex = 1:length(ADWWordList))
	currentWordRTs = correctSetProfCheckData.RT(strcmp(correctSetProfCheckData.Group,'PdMR') &...
       							strcmp(correctSetProfCheckData.Target,ADWWordList{ADWWordIndex}));
	[currentWordRTs outlierRTs] = SplitRTOutliers(currentWordRTs);
	plot(repmat(ADWWordIndex+0.2,1,length(currentWordRTs)),currentWordRTs,'.','Color',[0.6 0.6 0.6],'MarkerSize',20);
	plot(repmat(ADWWordIndex+0.2,1,length(outlierRTs)),outlierRTs,'.r','MarkerSize',20);
	plot(ADWWordIndex + [-0 0.4],repmat(geomean([currentWordRTs;outlierRTs]),1,2),'-r','LineWidth',5);
	plot(ADWWordIndex + [-0 0.4],repmat(geomean(currentWordRTs),1,2),'-','Color',[0.6 0.6 0.6],'LineWidth',5);
end
xticks(1:length(ADWWordList));
xticklabels(strcat(ADWWordList, '\newline ', ADWWordList)); %The newline ensures that both figures are the same size
axis([0.5 10.5 0 4300]);
ylabel('Response Time (ms)');
set(gca,'FontSize',FONT_SIZE);
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 FIGURE_WIDTH FIGURE_HEIGHT-2]);
outputFileName = ['.\Figures\Proficiency Check RTs for Distinct Words With Outliers'];
print(outputFileName,'-dpng','-r600');


figure;
hold on;
for(PoMRWordIndex = 1:length(PoMRWordList))
	currentWordRTs = correctSetProfCheckData.RT(strcmp(correctSetProfCheckData.Target,PoMRWordList{PoMRWordIndex}));
	[currentWordRTs outlierRTs] = SplitRTOutliers(currentWordRTs);
	plot(repmat(PoMRWordIndex-0.2,1,length(currentWordRTs)),currentWordRTs,'.k','MarkerSize',20);
	plot(repmat(PoMRWordIndex-0.2,1,length(outlierRTs)),outlierRTs,'.r','MarkerSize',20);
	plot(PoMRWordIndex + [-0.4 0],repmat(geomean([currentWordRTs;outlierRTs]),1,2),'-r','LineWidth',5);
	plot(PoMRWordIndex + [-0.4 0],repmat(geomean(currentWordRTs),1,2),'-k','LineWidth',5);
end
for(PdMRWordIndex = 1:length(PdMRWordList))
	currentWordRTs = correctSetProfCheckData.RT(strcmp(correctSetProfCheckData.Target,PdMRWordList{PdMRWordIndex}));
	[currentWordRTs outlierRTs] = SplitRTOutliers(currentWordRTs);
	plot(repmat(PdMRWordIndex+0.2,1,length(currentWordRTs)),currentWordRTs,'.','Color',[0.6 0.6 0.6],'MarkerSize',20);
	plot(repmat(PdMRWordIndex+0.2,1,length(outlierRTs)),outlierRTs,'.r','MarkerSize',20);
	plot(PdMRWordIndex + [0 0.4],repmat(geomean([currentWordRTs;outlierRTs]),1,2),'-r','LineWidth',5);
	plot(PdMRWordIndex + [0 0.4],repmat(geomean(currentWordRTs),1,2),'-','Color',[0.6 0.6 0.6],'LineWidth',5);
end
xticks(1:length(PoMRWordList));
xticklabels(strcat(PoMRWordList,'\newline',PdMRWordList));
axis([0.5 10.5 0 4300]);
ylabel('Response Time (ms)');
set(gca,'FontSize',FONT_SIZE);
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 FIGURE_WIDTH FIGURE_HEIGHT-2]);
outputFileName = ['.\Figures\Proficiency Check RTs for Similar Words With Outliers'];
print(outputFileName,'-dpng','-r600');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Figure 5A, Item level accuracy analysis across groups for distinct words
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Build a confusion matrix
ADWResponseList = [ADWWordList; {'?'}];
PoMRGroupADWConfusionMatrix = zeros(length(ADWWordList),length(ADWResponseList));
PdMRGroupADWConfusionMatrix = zeros(length(ADWWordList),length(ADWResponseList));
PoMRGroupADWSerialRecallData = serialRecallData(strcmp(serialRecallData.Group,'PoMR') & strcmp(serialRecallData.Condition,'ADW'),:);
PdMRGroupADWSerialRecallData = serialRecallData(strcmp(serialRecallData.Group,'PdMR') & strcmp(serialRecallData.Condition,'ADW'),:);
for(targetIndex = 1:length(ADWWordList))
	for(responseIndex = 1:length(ADWResponseList))
		PoMRGroupADWConfusionMatrix(targetIndex,responseIndex) = mean(mean(strcmp(PoMRGroupADWSerialRecallData{:,targetColumnIndex},ADWWordList{targetIndex}) & ...
								       strcmp(PoMRGroupADWSerialRecallData{:,responseColumnIndex},ADWResponseList{responseIndex})));
		PdMRGroupADWConfusionMatrix(targetIndex,responseIndex) = mean(mean(strcmp(PdMRGroupADWSerialRecallData{:,targetColumnIndex},ADWWordList{targetIndex}) & ...
								       strcmp(PdMRGroupADWSerialRecallData{:,responseColumnIndex},ADWResponseList{responseIndex})));
	end
end

%Normalize the confusion matrix to the frequency of each target item
normedPoMRGroupADWConfusionMatrix = PoMRGroupADWConfusionMatrix ./ repmat(sum(PoMRGroupADWConfusionMatrix,2),1,11);
normedPdMRGroupADWConfusionMatrix = PdMRGroupADWConfusionMatrix ./ repmat(sum(PdMRGroupADWConfusionMatrix,2),1,11);

%Indexing is to remove '?' responses
PoMRGroupADWDiagonal = diag(normedPoMRGroupADWConfusionMatrix(:,1:end-1));
PdMRGroupADWDiagonal = diag(normedPdMRGroupADWConfusionMatrix(:,1:end-1));

figure;
surf(normedPoMRGroupADWConfusionMatrix);
xticks(1:length(ADWResponseList));
xticklabels(ADWResponseList);
yticks(1:length(ADWWordList));
yticklabels(ADWWordList);

figure;
surf(normedPdMRGroupADWConfusionMatrix);
xticks(1:length(ADWResponseList));
xticklabels(ADWResponseList);
yticks(1:length(ADWWordList));
yticklabels(ADWWordList);

figure;
plot([.6 .9],[.6 .9],'--k','Linewidth',2);
hold on;
plot(PoMRGroupADWDiagonal,PdMRGroupADWDiagonal,'k.','MarkerSize',40);
linearFit = fitlm(PoMRGroupADWDiagonal,PdMRGroupADWDiagonal);
plot([0.695 0.797], [0.695 0.797] * linearFit.Coefficients.Estimate(2) + linearFit.Coefficients.Estimate(1),'-k','Linewidth',2);
axis([.6 .9 .6 .9]);
xticks([0.65:0.05:0.85]);
xticklabels({'','0.7','','0.8',''});
yticks([0.65:0.05:0.85]);
yticklabels({'','0.7','','0.8',''});
xlabel('Matched Group Accuracy');
ylabel('Mismatched Group Accuracy');
set(gca,'FontSize',FONT_SIZE);
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 FIGURE_WIDTH FIGURE_HEIGHT]);
outputFileName = ['.\Figures\Item Accuracy Comparison for Distinct Lists'];
print(outputFileName,'-dpng','-r600');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Figure 5B, Item level accuracy analysis across groups for similar words
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Build a confusion matrix
PoMRResponseList = [PoMRWordList; {'?'}];
PdMRResponseList = [PdMRWordList; {'?'}];
PoMRConfusionMatrix = zeros(length(PoMRWordList),length(PoMRResponseList));
PdMRConfusionMatrix = zeros(length(PdMRWordList),length(PdMRResponseList));
PoMRSerialRecallData = serialRecallData(strcmp(serialRecallData.Group,'PoMR') & strcmp(serialRecallData.Condition,'PoMR'),:);
PdMRSerialRecallData = serialRecallData(strcmp(serialRecallData.Group,'PdMR') & strcmp(serialRecallData.Condition,'PdMR'),:); 
for(targetIndex = 1:length(PoMRWordList))
	for(responseIndex = 1:length(PoMRResponseList))
		PoMRConfusionMatrix(targetIndex,responseIndex) = mean(mean(strcmp(PoMRSerialRecallData{:,targetColumnIndex},PoMRWordList{targetIndex}) & ...
								       strcmp(PoMRSerialRecallData{:,responseColumnIndex},PoMRResponseList{responseIndex})));
		PdMRConfusionMatrix(targetIndex,responseIndex) = mean(mean(strcmp(PdMRSerialRecallData{:,targetColumnIndex},PdMRWordList{targetIndex}) & ...
								       strcmp(PdMRSerialRecallData{:,responseColumnIndex},PdMRResponseList{responseIndex})));
	end
end

%Normalize the confusion matrix to the frequency of each target item
normedPoMRConfusionMatrix = PoMRConfusionMatrix ./ repmat(sum(PoMRConfusionMatrix,2),1,11);
normedPdMRConfusionMatrix = PdMRConfusionMatrix ./ repmat(sum(PdMRConfusionMatrix,2),1,11);

%Indexing is to remove '?' responses
PoMRDiagonal = diag(normedPoMRConfusionMatrix(:,1:end-1));
PdMRDiagonal = diag(normedPdMRConfusionMatrix(:,1:end-1));

figure;
surf(normedPoMRConfusionMatrix);
xticks(1:length(PoMRResponseList));
xticklabels(PoMRResponseList);
yticks(1:length(PoMRWordList));
yticklabels(PoMRWordList);

figure;
surf(normedPdMRConfusionMatrix);
xticks(1:length(PdMRResponseList));
xticklabels(PdMRResponseList);
yticks(1:length(PdMRWordList));
yticklabels(PdMRWordList);

figure;
plot([.35 .65],[.35 .65],'--k','Linewidth',2);
hold on;
plot(PoMRDiagonal,PdMRDiagonal,'k.','MarkerSize',40);
linearFit = fitlm(PoMRDiagonal,PdMRDiagonal);
plot([0.42 0.64], [0.42 0.64] * linearFit.Coefficients.Estimate(2) + linearFit.Coefficients.Estimate(1),'-k','Linewidth',2);
axis([.35 .65 .35 .65]);
xticks(0.4:0.05:0.6);
xticklabels({'0.4','','0.5','','0.6'});
yticks(0.4:0.05:0.6);
yticklabels({'0.4','','0.5','','0.6'});
xlabel('Matched Group Accuracy');
ylabel('Mismatched Group Accuracy');
set(gca,'FontSize',FONT_SIZE);
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 FIGURE_WIDTH FIGURE_HEIGHT]);
outputFileName = ['.\Figures\Item Accuracy Comparison for Similar Lists'];
print(outputFileName,'-dpng','-r600');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Figure 5 Item level accuracy analysis across groups for both word sets
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

figure;
plot([0 1],[0 1],'--k','Linewidth',2);
hold on;
plot(PoMRDiagonal,PdMRDiagonal,'.','Color',[0.6 0.6 0.6],'MarkerSize',40);
%gmregress can be obtained from:
%http://www.mathworks.com/matlabcentral/fileexchange/27918-gmregress
%Thanks to Trujillo-Ortiz and Hernandez-Walls for writing this.
%We don't use ordinary least squres regression because the measurement uncertainty
%on both axes is about equal, which would result in an underestimate of regression slope
similarWordLinearFit = gmregress(PoMRDiagonal,PdMRDiagonal);
plot([0.43 0.635], [0.43 0.635] * similarWordLinearFit(2) + similarWordLinearFit(1),'-','Color',[0.4 0.4 0.4],'Linewidth',4);
plot(PoMRGroupADWDiagonal,PdMRGroupADWDiagonal,'.','Color',[0.3 0.3 0.3],'MarkerSize',40);
distinctWordLinearFit = gmregress(PoMRGroupADWDiagonal,PdMRGroupADWDiagonal);
plot([0.7 0.795], [0.7 0.795] * distinctWordLinearFit(2) + distinctWordLinearFit(1),'-k','Linewidth',4);
axis([.35 .83 .35 .83]);
axis square;
xticks(0.4:0.05:0.9);
xticklabels({'0.4','','0.5','','0.6','','0.7','','0.8','','0.9'});
yticks(0.4:0.05:0.9);
yticklabels({'0.4','','0.5','','0.6','','0.7','','0.8','','0.9'});
xlabel('Matched Label Group Accuracy');
ylabel('Mismatched Label Group Accuracy');
set(gca,'FontSize',FONT_SIZE);
%I want this one ot be square, hence the repeated FIGURE_HEIGHT
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 FIGURE_HEIGHT+2 FIGURE_HEIGHT+2]);
outputFileName = ['.\Figures\Item Accuracy Comparison for Both Lists'];
print(outputFileName,'-dpng','-r600');

[similarSignRankItemP,~,similarSignRankItemStats]=signrank(PoMRDiagonal,PdMRDiagonal);
[similarSpearmanRho, similarSpearmanP] = corr(PoMRDiagonal,PdMRDiagonal,'Type','Spearman');
[distinctSignRankItemP,~,distinctSignRankItemStats]=signrank(PoMRGroupADWDiagonal,PdMRGroupADWDiagonal);
[distinctSpearmanRho, distinctSpearmanP] = corr(PoMRGroupADWDiagonal,PdMRGroupADWDiagonal,'Type','Spearman');

disp('********************************************************************************');
disp(['Similar Word Item Level Sign Rank P: ' num2str(similarSignRankItemP)]);
disp(['Similar Word Rank Correlation Rho: ' num2str(similarSpearmanRho) ', p = ' num2str(similarSpearmanP)]);
disp(['Distinct Word Item Level Sign Rank P: ' num2str(distinctSignRankItemP)]);
disp(['Distinct Word Rank Correlation Rho: ' num2str(distinctSpearmanRho) ', p = ' num2str(distinctSpearmanP)]);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Figure 6A, serial position curve for distinct word lists across both groups
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure;
ADWinPoMRGroupTrialIndex = strcmp(serialRecallData.Group,'PoMR') & strcmp(serialRecallData.Condition,'ADW');
plot(mean(serialRecallData{ADWinPoMRGroupTrialIndex,correctColumnIndex}),'.k-','Linewidth',2,'MarkerSize',30);
hold on;
ADWinPdMRGroupTrialIndex = strcmp(serialRecallData.Group,'PdMR') & strcmp(serialRecallData.Condition,'ADW');
plot(mean(serialRecallData{ADWinPdMRGroupTrialIndex,correctColumnIndex}),'.-','Color',[0.6 0.6 0.6],'LineWidth',2,'MarkerSize',30);
xticks(1:6);
axis([0.9 6.1 0 1]);
xlabel('Serial Position')
ylabel('Correct Response Rate');
set(gca,'FontSize',FONT_SIZE);
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 FIGURE_WIDTH/2 FIGURE_HEIGHT-2]);
outputFileName = ['.\Figures\Serial Position Curves for Distinct Lists'];
print(outputFileName,'-dpng','-r600');

for(positionIndex = 1:6);
	PoMRGroupTrialsCorrect = sum(serialRecallData{ADWinPoMRGroupTrialIndex,correctColumnIndex(positionIndex)});
	PoMRGroupTrialsIncorrect = sum(ADWinPoMRGroupTrialIndex) - PoMRGroupTrialsCorrect;
	PdMRGroupTrialsCorrect = sum(serialRecallData{ADWinPdMRGroupTrialIndex,correctColumnIndex(positionIndex)});
	PdMRGroupTrialsIncorrect = sum(ADWinPdMRGroupTrialIndex) - PdMRGroupTrialsCorrect;
	[~,distinctSPCfisherP(positionIndex)] =  fishertest([PoMRGroupTrialsCorrect, PoMRGroupTrialsIncorrect;...
							PdMRGroupTrialsCorrect, PdMRGroupTrialsIncorrect]);
end
disp('********************************************************************************');
disp('Serial Position Curve Difference Tests for distinct lists')
disp(num2str(distinctSPCfisherP));
disp(['Significant values are < ' num2str(0.05/6) ' after Bonferroni correction']);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Figure 6B, serial position curve for spurious/veridical word lists across both groups
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure;
PoMRTrialIndex = strcmp(serialRecallData.Condition,'PoMR');
plot(mean(serialRecallData{PoMRTrialIndex,correctColumnIndex}),'.k-','Linewidth',2,'MarkerSize',30);
hold on;
PdMRTrialIndex = strcmp(serialRecallData.Condition,'PdMR');
plot(mean(serialRecallData{PdMRTrialIndex,correctColumnIndex}),'.-','Color',[0.6 0.6 0.6],'LineWidth',2,'MarkerSize',30);
xticks(1:6);
axis([0.9 6.1 0 1]);
xlabel('Serial Position')
ylabel('Correct Response Rate');
set(gca,'FontSize',FONT_SIZE);
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 FIGURE_WIDTH/2 FIGURE_HEIGHT-2]);
outputFileName = ['.\Figures\Serial Position Curves for Similar Lists'];
print(outputFileName,'-dpng','-r600');

for(positionIndex = 1:6);
	PoMRTrialsCorrect = sum(serialRecallData{PoMRTrialIndex,correctColumnIndex(positionIndex)});
	PoMRTrialsIncorrect = sum(PoMRTrialIndex) - PoMRTrialsCorrect;
	PdMRTrialsCorrect = sum(serialRecallData{PdMRTrialIndex,correctColumnIndex(positionIndex)});
	PdMRTrialsIncorrect = sum(PdMRTrialIndex) - PdMRTrialsCorrect;
	[~,similarSPCfisherP(positionIndex)] =  fishertest([PoMRTrialsCorrect, PoMRTrialsIncorrect;...
							PdMRTrialsCorrect, PdMRTrialsIncorrect]);
end
disp('********************************************************************************');
disp('Serial Position Curve Difference Tests for similar lists')
disp(num2str(similarSPCfisherP));
disp(['Significant values are < ' num2str(0.05/6) ' after Bonferroni correction']);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Figure 6B supplement, same analysis but with the three participants who went in
%the wrong direction in the similar word, matched label condition in figure 1
%removed.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure;
PoMRTrialIndexWithoutOutliers = strcmp(serialRecallData.Condition,'PoMR') & all(serialRecallData.Subject ~= outlierSubjectNumbers',2);
plot(mean(serialRecallData{PoMRTrialIndexWithoutOutliers,correctColumnIndex}),'.k-','Linewidth',2,'MarkerSize',30);
hold on;
%PdMRTrialIndex = strcmp(serialRecallData.Condition,'PdMR');
plot(mean(serialRecallData{PdMRTrialIndex,correctColumnIndex}),'.-','Color',[0.6 0.6 0.6],'LineWidth',2,'MarkerSize',30);
xticks(1:6);
axis([0.9 6.1 0 1]);
xlabel('Serial Position')
ylabel('Correct Response Rate');
set(gca,'FontSize',FONT_SIZE);
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 FIGURE_WIDTH/2 FIGURE_HEIGHT-2]);
title('Figure 2B Supplement');
%outputFileName = ['.\Figures\Serial Position Curves for Similar Lists Without Outliers'];
%print(outputFileName,'-dpng','-r600');

for(positionIndex = 1:6);
	PoMRTrialsCorrectWithoutOutliers = sum(serialRecallData{PoMRTrialIndexWithoutOutliers,correctColumnIndex(positionIndex)});
	PoMRTrialsIncorrectWithoutOutliers = sum(PoMRTrialIndexWithoutOutliers) - PoMRTrialsCorrectWithoutOutliers;
	PdMRTrialsCorrect = sum(serialRecallData{PdMRTrialIndex,correctColumnIndex(positionIndex)});
	PdMRTrialsIncorrect = sum(PdMRTrialIndex) - PdMRTrialsCorrect;
	[~,similarSPCfisherPWithoutOutliers(positionIndex)] =  fishertest([PoMRTrialsCorrectWithoutOutliers, PoMRTrialsIncorrectWithoutOutliers;...
									PdMRTrialsCorrect, PdMRTrialsIncorrect]);
end
%With those three participants removed the difference at position 5 disappears, which
%doesn't substantially change our interpretation of the results.

%disp('********************************************************************************');
%disp('Serial Position Curve Difference Tests for similar lists, with outliers removed')
%disp(num2str(similarSPCfisherPWithoutOutliers));
%disp(['Significant values are < ' num2str(0.05/6) ' after Bonferroni correction']);



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Item Recall and Correct-In-Place analysis
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
averageADWItemMatches = nan(length(subjects),1);
averageADWCorrectInPlace = nan(length(subjects),1);
averagePoMRItemMatches = nan(length(subjects),1);
averagePoMRCorrectInPlace = nan(length(subjects),1);
averagePdMRItemMatches = nan(length(subjects),1);
averagePdMRCorrectInPlace = nan(length(subjects),1);

for(subjectIndex = 1:length(subjects))
	currentSubject = subjects(subjectIndex);
	currentSubjectData = serialRecallData(serialRecallData.Subject == currentSubject,:);
	if(any(strcmp(currentSubjectData.Condition,'PoMR')))
		%This subject was in the veridical group
		currentSubjectDistinctData = currentSubjectData(strcmp(currentSubjectData.Condition,'ADW'),:);
		%I can figure out how to do this in a vectorized way, so it's a loop.
		for(trialIndex = 1:height(currentSubjectDistinctData))
			%Calculate number of items recalled on each trial in any position
			itemMatches = cellfun(@(x) strcmp(x,currentSubjectDistinctData{trialIndex,targetColumnIndex}),...
								currentSubjectDistinctData{trialIndex,responseColumnIndex}', 'UniformOutput',false);
			itemMatches = vertcat(itemMatches{:}); %I don't understand why matlab insists on uniformOutput being false above.
			nItemMatches(trialIndex) = sum(sum(itemMatches));
			
			%Calculate correct-in-place as a ratio of items in correct positions divided by items recalled in any position
			nPlaceMatches = sum(currentSubjectDistinctData{trialIndex,correctColumnIndex});
			%Guard against a div by zero
			if(nItemMatches(trialIndex) == 0)
				correctInPlace(trialIndex) = 0;
			else
				correctInPlace(trialIndex) = nPlaceMatches / nItemMatches(trialIndex);
			end
		end

		averageADWItemMatches(subjectIndex) = mean(nItemMatches);
		averageADWCorrectInPlace(subjectIndex) = mean(correctInPlace);

		currentSubjectSimilarData = currentSubjectData(strcmp(currentSubjectData.Condition,'PoMR'),:);
		for(trialIndex = 1:height(currentSubjectSimilarData))
			%Calculate number of items recalled on each trial in any position
			itemMatches = cellfun(@(x) strcmp(x,currentSubjectSimilarData{trialIndex,targetColumnIndex}),...
								currentSubjectSimilarData{trialIndex,responseColumnIndex}', 'UniformOutput',false);
			itemMatches = vertcat(itemMatches{:}); %I don't understand why matlab insists on uniformOutput being false above.
			nItemMatches(trialIndex) = sum(sum(itemMatches));
			
			%Calculate correct-in-place as a ratio of items in correct positions divided by items recalled in any position
			nPlaceMatches = sum(currentSubjectSimilarData{trialIndex,correctColumnIndex});
			%Guard against a div by zero
			if(nItemMatches(trialIndex) == 0)
				correctInPlace(trialIndex) = 0;
			else
				correctInPlace(trialIndex) = nPlaceMatches / nItemMatches(trialIndex);
			end
		end

		averagePoMRItemMatches(subjectIndex) = mean(nItemMatches);
		averagePoMRCorrectInPlace(subjectIndex) = mean(correctInPlace);
	
	elseif(any(strcmp(currentSubjectData.Condition,'PdMR')))
		%This subject was in the spurious group
		currentSubjectDistinctData = currentSubjectData(strcmp(currentSubjectData.Condition,'ADW'),:);
		for(trialIndex = 1:height(currentSubjectDistinctData))
			%Calculate number of items recalled on each trial in any position
			itemMatches = cellfun(@(x) strcmp(x,currentSubjectDistinctData{trialIndex,targetColumnIndex}),...
								currentSubjectDistinctData{trialIndex,responseColumnIndex}', 'UniformOutput',false);
			itemMatches = vertcat(itemMatches{:}); %I don't understand why matlab insists on uniformOutput being false above.
			nItemMatches(trialIndex) = sum(sum(itemMatches));
			
			%Calculate correct-in-place as a ratio of items in correct positions divided by items recalled in any position
			nPlaceMatches = sum(currentSubjectDistinctData{trialIndex,correctColumnIndex});
			%Guard against a div by zero
			if(nItemMatches(trialIndex) == 0)
				correctInPlace(trialIndex) = 0;
			else
				correctInPlace(trialIndex) = nPlaceMatches / nItemMatches(trialIndex);
			end
		end

		averageADWItemMatches(subjectIndex) = mean(nItemMatches);
		averageADWCorrectInPlace(subjectIndex) = mean(correctInPlace);

		currentSubjectSimilarData = currentSubjectData(strcmp(currentSubjectData.Condition,'PdMR'),:);
		for(trialIndex = 1:height(currentSubjectSimilarData))
			%Calculate number of items recalled on each trial in any position
			itemMatches = cellfun(@(x) strcmp(x,currentSubjectSimilarData{trialIndex,targetColumnIndex}),...
								currentSubjectSimilarData{trialIndex,responseColumnIndex}', 'UniformOutput',false);
			itemMatches = vertcat(itemMatches{:}); %I don't understand why matlab insists on uniformOutput being false above.
			nItemMatches(trialIndex) = sum(sum(itemMatches));
			
			%Calculate correct-in-place as a ratio of items in correct positions divided by items recalled in any position
			nPlaceMatches = sum(currentSubjectSimilarData{trialIndex,correctColumnIndex});
			%Guard against a div by zero
			if(nItemMatches(trialIndex) == 0)
				correctInPlace(trialIndex) = 0;
			else
				correctInPlace(trialIndex) = nPlaceMatches / nItemMatches(trialIndex);
			end
		end

		averagePdMRItemMatches(subjectIndex) = mean(nItemMatches);
		averagePdMRCorrectInPlace(subjectIndex) = mean(correctInPlace);
	
	end
end

disp(['Average number of items correctly recalled for distinct lists: ' num2str(mean(averageADWItemMatches))]);
disp(['Average proportion of items recalled items in correct positions for distinct lists: ' num2str(mean(averageADWCorrectInPlace))]);
disp(['Average number of items correctly recalled for similar lists with original labels: ' num2str(mean(averagePoMRItemMatches,'omitnan'))]);
disp(['Average proportion of items recalled items in correct positions for similar lists with original labels: ' num2str(mean(averagePoMRCorrectInPlace,'omitnan'))]);
disp(['Average number of items correctly recalled for similar lists with shifted labels: ' num2str(mean(averagePdMRItemMatches,'omitnan'))]);
disp(['Average proportion of items recalled items in correct positions for similar lists with shifted labels: ' num2str(mean(averagePdMRCorrectInPlace,'omitnan'))]);

[itemMatchesPSEP, ~, itemMatchesPSEStats] = signrank(averageADWItemMatches(~isnan(averagePoMRItemMatches)),averagePoMRItemMatches(~isnan(averagePoMRItemMatches)),'method','exact');
[correctInPlacePSEP, ~, correctInPlacePSEStats] = signrank(averageADWCorrectInPlace(~isnan(averagePoMRCorrectInPlace)),averagePoMRCorrectInPlace(~isnan(averagePoMRCorrectInPlace)),'method','exact');

%The exact method is commented to save time when the whole script is run, but is where the reported stats came from
[itemMatchesP, ~, itemMatchesStats] = ranksum(averagePoMRItemMatches(~isnan(averagePoMRItemMatches)),averagePdMRItemMatches(~isnan(averagePdMRItemMatches)));%,'method','exact');
[correctInPlaceP, ~, correctInPlaceStats] = ranksum(averagePoMRCorrectInPlace(~isnan(averagePoMRCorrectInPlace)),averagePdMRCorrectInPlace(~isnan(averagePdMRCorrectInPlace)));%,'method','exact');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Supplemental Analysis, RTs across serial positions in lists
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for(positionIndex = 1:length(targetColumnIndex))
	correctResponsesForThisPosition = serialRecallData{:,correctColumnIndex(positionIndex)};
	RTsForThisPosition = serialRecallData{:,RTColumnIndex(positionIndex)};

	%Correct responses
	PoMRGroupADWRTsForThisPosition = RTsForThisPosition(correctResponsesForThisPosition &...
								strcmp(serialRecallData.Group,'PoMR') &...
								strcmp(serialRecallData.Condition,'ADW'));
	[PoMRGroupADWRTsForThisPosition PoMRGroupADWOutlierRTs] = SplitRTOutliers(PoMRGroupADWRTsForThisPosition);
	propPoMRGroupADWOutliers(positionIndex) = numel(PoMRGroupADWOutlierRTs)/...
							numel([PoMRGroupADWRTsForThisPosition;PoMRGroupADWOutlierRTs]);

	PdMRGroupADWRTsForThisPosition = RTsForThisPosition(correctResponsesForThisPosition &...
								strcmp(serialRecallData.Group,'PdMR') &...
								strcmp(serialRecallData.Condition,'ADW'));
	[PdMRGroupADWRTsForThisPosition PdMRGroupADWOutlierRTs] = SplitRTOutliers(PdMRGroupADWRTsForThisPosition);
	propPdMRGroupADWOutliers(positionIndex) = numel(PdMRGroupADWOutlierRTs)/...
							numel([PdMRGroupADWRTsForThisPosition;PdMRGroupADWOutlierRTs]);

	meanCorrectResponsePoMRGroupADWRT(positionIndex) = geomean(PoMRGroupADWRTsForThisPosition);
	meanCorrectResponsePdMRGroupADWRT(positionIndex) = geomean(PdMRGroupADWRTsForThisPosition);

	distinctWordSPCRTRankSumP(positionIndex) = ranksum(PoMRGroupADWRTsForThisPosition,...
								PdMRGroupADWRTsForThisPosition);


	PoMRRTsForThisPosition = RTsForThisPosition(correctResponsesForThisPosition &...
					strcmp(serialRecallData.Condition,'PoMR'));
	[PoMRRTsForThisPosition PoMROutlierRTs] = SplitRTOutliers(PoMRRTsForThisPosition);
	propPoMROutliers(positionIndex) = numel(PoMROutlierRTs)/...
						numel([PoMRRTsForThisPosition;PoMROutlierRTs]);

	PdMRRTsForThisPosition = RTsForThisPosition(correctResponsesForThisPosition &...
					strcmp(serialRecallData.Condition,'PdMR'));
	[PdMRRTsForThisPosition PdMROutlierRTs] = SplitRTOutliers(PdMRRTsForThisPosition);
	propPdMROutliers(positionIndex) = numel(PdMROutlierRTs)/...
						numel([PdMRRTsForThisPosition;PdMROutlierRTs]);

	meanCorrectResponsePoMRRT(positionIndex) = geomean(PoMRRTsForThisPosition);
	meanCorrectResponsePdMRRT(positionIndex) = geomean(PdMRRTsForThisPosition);

	similarWordSPCRTRankSumP(positionIndex) = ranksum(PoMRRTsForThisPosition,...
								PdMRRTsForThisPosition);

	crossWordListSPCRTRankSumP(positionIndex) = ranksum([PoMRGroupADWRTsForThisPosition; PdMRGroupADWRTsForThisPosition],...
							[PoMRRTsForThisPosition; PdMRRTsForThisPosition]);

	%Incorrect responses
	incorrectResponsePoMRGroupADWRTsForThisPosition =  RTsForThisPosition(~correctResponsesForThisPosition &...
       											strcmp(serialRecallData.Group,'PoMR') &...
										       	strcmp(serialRecallData.Condition,'ADW'));
	[incorrectResponsePoMRGroupADWRTsForThisPosition incorrectResponsePoMRGroupADWOutlierRTs] = SplitRTOutliers(incorrectResponsePoMRGroupADWRTsForThisPosition);
	incorrectResponsePdMRGroupADWRTsForThisPosition =  RTsForThisPosition(~correctResponsesForThisPosition &...
       											strcmp(serialRecallData.Group,'PdMR') &...
										       	strcmp(serialRecallData.Condition,'ADW'));
	[incorrectResponsePdMRGroupADWRTsForThisPosition incorrectResponsePdMRGroupADWOutlierRTs] = SplitRTOutliers(incorrectResponsePdMRGroupADWRTsForThisPosition);
	meanIncorrectResponsePoMRGroupADWRT(positionIndex) = geomean(incorrectResponsePoMRGroupADWRTsForThisPosition);
	meanIncorrectResponsePdMRGroupADWRT(positionIndex) = geomean(incorrectResponsePdMRGroupADWRTsForThisPosition);

	incorrectResponseDistinctWordSPCRTRankSumP(positionIndex) = ranksum(incorrectResponsePoMRGroupADWRTsForThisPosition,...
								incorrectResponsePdMRGroupADWRTsForThisPosition);


	incorrectResponsePoMRRTsForThisPosition = RTsForThisPosition(~correctResponsesForThisPosition &...
						strcmp(serialRecallData.Condition,'PoMR'));
	[incorrectResponsePoMRRTsForThisPosition incorrectResponsePoMROutlierRTs] = SplitRTOutliers(incorrectResponsePoMRRTsForThisPosition);	
	incorrectResponsePdMRRTsForThisPosition = RTsForThisPosition(~correctResponsesForThisPosition &...
						strcmp(serialRecallData.Condition,'PdMR'));
	[incorrectResponsePdMRRTsForThisPosition incorrectResponsePdMROutlierRTs] = SplitRTOutliers(incorrectResponsePdMRRTsForThisPosition);	

	meanIncorrectResponsePoMRRT(positionIndex) = geomean(incorrectResponsePoMRRTsForThisPosition);
	meanIncorrectResponsePdMRRT(positionIndex) = geomean(incorrectResponsePdMRRTsForThisPosition);

	incorrectResponseSimilarWordSPCRTRankSumP(positionIndex) = ranksum(incorrectResponsePoMRRTsForThisPosition,...
										incorrectResponsePdMRRTsForThisPosition);


	incorrectResponseCrossWordListSPCRTRankSumP(positionIndex) = ranksum([incorrectResponsePoMRGroupADWRTsForThisPosition;...
       										incorrectResponsePdMRGroupADWRTsForThisPosition],...
										[incorrectResponsePoMRRTsForThisPosition;...
										incorrectResponsePdMRRTsForThisPosition]);
end

figure;
plot(meanCorrectResponsePoMRGroupADWRT,'.k-','Linewidth',2,'MarkerSize',30);
hold on;
plot(meanCorrectResponsePdMRGroupADWRT,'.-','Color',[0.6 0.6 0.6],'Linewidth',2,'MarkerSize',30);
xticks(1:6);
axis([0.9 6.1 0 4500]);
xlabel('Position')
ylabel('Response Time (ms)');
set(gca,'FontSize',FONT_SIZE);
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 FIGURE_WIDTH/2 FIGURE_HEIGHT-2]);
outputFileName = ['.\Figures\Serial Position RT Curves for Correct Responses in Distinct Lists'];
print(outputFileName,'-dpng','-r600');

figure;
plot(meanCorrectResponsePoMRRT,'.k-','Linewidth',2,'MarkerSize',30);
hold on;
plot(meanCorrectResponsePdMRRT,'.-','Color',[0.6 0.6 0.6],'Linewidth',2,'MarkerSize',30);
xticks(1:6);
axis([0.9 6.1 0 4500]);
xlabel('Position')
ylabel('Response Time (ms)');
set(gca,'FontSize',FONT_SIZE);
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 FIGURE_WIDTH/2 FIGURE_HEIGHT-2]);
outputFileName = ['.\Figures\Serial Position RT Curves for Correct Responses in Similar Lists'];
print(outputFileName,'-dpng','-r600');


figure;
plot(meanIncorrectResponsePoMRGroupADWRT,'.k-','Linewidth',2,'MarkerSize',30);
hold on;
plot(meanIncorrectResponsePdMRGroupADWRT,'.-','Color',[0.6 0.6 0.6],'Linewidth',2,'MarkerSize',30);
xticks(1:6);
axis([0.9 6.1 0 4500]);
xlabel('Position')
ylabel('Response Time (ms)');
set(gca,'FontSize',FONT_SIZE);
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 FIGURE_WIDTH/2 FIGURE_HEIGHT-2]);
outputFileName = ['.\Figures\Serial Position RT Curves for Incorrect Responses in Distinct Lists'];
print(outputFileName,'-dpng','-r600');

figure;
plot(meanIncorrectResponsePoMRRT,'.k-','Linewidth',2,'MarkerSize',30);
hold on;
plot(meanIncorrectResponsePdMRRT,'.-','Color',[0.6 0.6 0.6],'Linewidth',2,'MarkerSize',30);
xticks(1:6);
axis([0.9 6.1 0 4500]);
xlabel('Position')
ylabel('Response Time (ms)');
set(gca,'FontSize',FONT_SIZE);
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 FIGURE_WIDTH/2 FIGURE_HEIGHT-2]);
outputFileName = ['.\Figures\Serial Position RT Curves for Incorrect Responses in Similar Lists'];
print(outputFileName,'-dpng','-r600');


%Proportion of outliers removed
disp('********************************************************************************');
disp('Number of Outliers removed for each condition in the serial position curve lists');
[maxOutliers, maxPosition] = max(propPoMRGroupADWOutliers);
disp(['Distinct Words, Matched Group: max proportion = ' num2str(maxOutliers) ', position ' num2str(maxPosition)]);
[maxOutliers, maxPosition] = max(propPdMRGroupADWOutliers);
disp(['Distinct Words, Mismatched Group: max proportion = ' num2str(maxOutliers) ', position ' num2str(maxPosition)]);
[maxOutliers, maxPosition] = max(propPoMROutliers);
disp(['Similar Words, Matched Group: max proportion = ' num2str(maxOutliers) ', position ' num2str(maxPosition)]);
[maxOutliers, maxPosition] = max(propPdMROutliers);
disp(['Similar Words, Mismatched Group: max proportion = ' num2str(maxOutliers) ', position ' num2str(maxPosition)]);

%Within word set difference test
disp('********************************************************************************');
disp('Serial Recall RT Differences For Distinct Words, Correct Responses')
disp(num2str(distinctWordSPCRTRankSumP));
disp(['Significant values are < ' num2str(0.05/6) ' after Bonferroni correction']);

disp('Serial Recall RT Differences For Similar Words, Correct Responses')
disp(num2str(similarWordSPCRTRankSumP));
disp(['Significant values are < ' num2str(0.05/6) ' after Bonferroni correction']);

disp('********************************************************************************');
disp('Serial Recall RT Differences For Distinct Words, Incorrect Responses')
disp(num2str(incorrectResponseDistinctWordSPCRTRankSumP));
disp(['Significant values are < ' num2str(0.05/6) ' after Bonferroni correction']);

disp('Serial Recall RT Differences For Similar Words, Incorrect Responses')
disp(num2str(incorrectResponseSimilarWordSPCRTRankSumP));
disp(['Significant values are < ' num2str(0.05/6) ' after Bonferroni correction']);

%Cross word set difference test
disp('********************************************************************************');
disp('Serial Recall RT Differences Across Word Lists, Averaged Cross Groups')
disp(num2str(crossWordListSPCRTRankSumP));
disp(['Significant values are < ' num2str(0.05/6) ' after Bonferroni correction']);
crossListCorrectSPCRTDifference = geomean([meanCorrectResponsePoMRRT;	meanCorrectResponsePdMRRT]) -...
					geomean([meanCorrectResponsePoMRGroupADWRT;	meanCorrectResponsePdMRGroupADWRT])

disp('Serial Recall RT Differences Across Word Lists For Incorrect Responses, Averaged Cross Groups')
disp(num2str(incorrectResponseCrossWordListSPCRTRankSumP));
disp(['Significant values are < ' num2str(0.05/6) ' after Bonferroni correction']);
crossListIncorrectSPCRTDifference = geomean([meanIncorrectResponsePoMRRT;meanIncorrectResponsePdMRRT])-...
					geomean([meanIncorrectResponsePoMRGroupADWRT;meanIncorrectResponsePdMRGroupADWRT])



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Supplemental Analysis, Gold-MSI General Scale correlation with serial recall performance
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure;
plot(MSISummary.Score,MSISummary.DistinctPerformance,'.k','MarkerSize',20);
axis([25 120 0 1]);
xlabel('MSI General Subscale');
ylabel('Proportion Correct Responses For Distinct Words');

figure;
plot(MSISummary.Score,MSISummary.PoMRPerformance,'.k','MarkerSize',20);
axis([25 120 0 1]);
xlabel('MSI General Subscale');
ylabel('Proportion Correct Responses For Similar Words, Matched Labels');

figure;
plot(MSISummary.Score,MSISummary.PdMRPerformance,'.k','MarkerSize',20);
axis([25 120 0 1]);
xlabel('MSI General Subscale');
ylabel('Proportion Correct Responses For Similar Words, Mismatched Labels');

disp('********************************************************************************');
disp('Gold-MSI General Subscale correlation with proportion correct responses in serial recall');
[MSIDistinctRho, MSIDistinctP] = corr(MSISummary.Score(~isnan(MSISummary.Score)),MSISummary.DistinctPerformance(~isnan(MSISummary.Score)));
disp(['Correlation with distinct words, rho = ' num2str(MSIDistinctRho) ', p = ' num2str(MSIDistinctP)]);
[MSIMatchedRho, MSIMatchedP] = corr(MSISummary.Score(~isnan(MSISummary.Score) & ~isnan(MSISummary.PoMRPerformance)),...
					MSISummary.PoMRPerformance(~isnan(MSISummary.Score) & ~isnan(MSISummary.PoMRPerformance)));
disp(['Correlation with distinct words, rho = ' num2str(MSIMatchedRho) ', p = ' num2str(MSIMatchedP)]);
[MSIMismatchedRho, MSIMismatchedP] = corr(MSISummary.Score(~isnan(MSISummary.Score) & ~isnan(MSISummary.PdMRPerformance)),...
					MSISummary.PdMRPerformance(~isnan(MSISummary.Score) & ~isnan(MSISummary.PdMRPerformance)));
disp(['Correlation with distinct words, rho = ' num2str(MSIMismatchedRho) ', p = ' num2str(MSIMismatchedP)]);

%This analysis is briefly mentioned in the methods section. Because we did not 
%find a signification relationship between overall accuracy and Gold-MSI we did not
%pursue further analysis

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Supplemental analysis, serial recall in each task split by condition order
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%This analysis shows a small main effect of practice on recall accuracy,
%the second condition was slightly better than the first condition, but not
%in a way that substantially affected our interpretation of the results

for(subjectIndex = 1:length(subjects))
	serialRecallData.FirstCondition(serialRecallData.Subject == subjects(subjectIndex)) = ...
		serialRecallData.Condition(find(serialRecallData.Subject==subjects(subjectIndex),1));
end


figure;
PoMRGroupADWFirstTrialIndex = strcmp(serialRecallData.Condition,'ADW') & strcmp(serialRecallData.Group,'PoMR') & strcmp(serialRecallData.FirstCondition,'ADW');
PoMRGroupADWSecondTrialIndex = strcmp(serialRecallData.Condition,'ADW') & strcmp(serialRecallData.Group,'PoMR')  & strcmp(serialRecallData.FirstCondition,'PoMR');
plot(mean(serialRecallData{PoMRGroupADWFirstTrialIndex,correctColumnIndex}),'.k-','Linewidth',2,'MarkerSize',30);
hold on;
plot(mean(serialRecallData{PoMRGroupADWSecondTrialIndex,correctColumnIndex}),'.k--','Linewidth',1,'MarkerSize',20);
PdMRGroupADWFirstTrialIndex = strcmp(serialRecallData.Condition,'ADW') & strcmp(serialRecallData.Group,'PdMR')  & strcmp(serialRecallData.FirstCondition,'ADW');
PdMRGroupADWSecondTrialIndex = strcmp(serialRecallData.Condition,'ADW') & strcmp(serialRecallData.Group,'PdMR')  & strcmp(serialRecallData.FirstCondition,'PdMR');
plot(mean(serialRecallData{PdMRGroupADWFirstTrialIndex,correctColumnIndex}),'.-','Color',[0.6 0.6 0.6],'LineWidth',2,'MarkerSize',30);
plot(mean(serialRecallData{PdMRGroupADWSecondTrialIndex,correctColumnIndex}),'.--','Color',[0.6 0.6 0.6],'LineWidth',1,'MarkerSize',20);
xticks(1:6);
axis([0.9 6.1 0 1]);
xlabel('Serial Position')
ylabel('Correct Response Rate');
set(gca,'FontSize',FONT_SIZE);
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 FIGURE_WIDTH/2 FIGURE_HEIGHT-2]);
outputFileName = ['.\Figures\Serial Position Curves for Distinct Lists Split by Condition Order'];
print(outputFileName,'-dpng','-r600');

for(positionIndex = 1:6);
	PoMRGroupADWFirstTrialsCorrect = sum(serialRecallData{PoMRGroupADWFirstTrialIndex,correctColumnIndex(positionIndex)});
	PoMRGroupADWFirstTrialsIncorrect = sum(PoMRGroupADWFirstTrialIndex) - PoMRGroupADWFirstTrialsCorrect;
	PoMRGroupADWSecondTrialsCorrect = sum(serialRecallData{PoMRGroupADWSecondTrialIndex,correctColumnIndex(positionIndex)});
	PoMRGroupADWSecondTrialsIncorrect = sum(PoMRGroupADWSecondTrialIndex) - PoMRGroupADWSecondTrialsCorrect;
	[~,veridicalSPCfisherP(positionIndex)] =  fishertest([PoMRGroupADWFirstTrialsCorrect, PoMRGroupADWFirstTrialsIncorrect;...
							PoMRGroupADWSecondTrialsCorrect, PoMRGroupADWSecondTrialsIncorrect]);
end
disp('********************************************************************************');
disp('Serial Position Curve Difference Tests for Condition Order, Distinct Lists Veridical Group')
disp(num2str(veridicalSPCfisherP));
disp(['Significant values are < ' num2str(0.05/6) ' after Bonferroni correction']);

for(positionIndex = 1:6);
	PdMRGroupADWFirstTrialsCorrect = sum(serialRecallData{PdMRGroupADWFirstTrialIndex,correctColumnIndex(positionIndex)});
	PdMRGroupADWFirstTrialsIncorrect = sum(PdMRGroupADWFirstTrialIndex) - PdMRGroupADWFirstTrialsCorrect;
	PdMRGroupADWSecondTrialsCorrect = sum(serialRecallData{PdMRGroupADWSecondTrialIndex,correctColumnIndex(positionIndex)});
	PdMRGroupADWSecondTrialsIncorrect = sum(PdMRGroupADWSecondTrialIndex) - PdMRGroupADWSecondTrialsCorrect;
	[~,spuriousSPCfisherP(positionIndex)] =  fishertest([PdMRGroupADWFirstTrialsCorrect, PdMRGroupADWFirstTrialsIncorrect;...
							PdMRGroupADWSecondTrialsCorrect, PdMRGroupADWSecondTrialsIncorrect]);
end
disp('********************************************************************************');
disp('Serial Position Curve Difference Tests for Condition Order, Distinct Lists Spurious Group')
disp(num2str(spuriousSPCfisherP));
disp(['Significant values are < ' num2str(0.05/6) ' after Bonferroni correction']);


figure;
PoMRFirstTrialIndex = strcmp(serialRecallData.Condition,'PoMR') & strcmp(serialRecallData.FirstCondition,'PoMR');
PoMRSecondTrialIndex = strcmp(serialRecallData.Condition,'PoMR') & strcmp(serialRecallData.FirstCondition,'ADW');
plot(mean(serialRecallData{PoMRFirstTrialIndex,correctColumnIndex}),'.k-','Linewidth',2,'MarkerSize',30);
hold on;
plot(mean(serialRecallData{PoMRSecondTrialIndex,correctColumnIndex}),'.k--','Linewidth',1,'MarkerSize',20);
PdMRFirstTrialIndex = strcmp(serialRecallData.Condition,'PdMR') & strcmp(serialRecallData.FirstCondition,'PdMR');
PdMRSecondTrialIndex = strcmp(serialRecallData.Condition,'PdMR') & strcmp(serialRecallData.FirstCondition,'ADW');
plot(mean(serialRecallData{PdMRFirstTrialIndex,correctColumnIndex}),'.-','Color',[0.6 0.6 0.6],'LineWidth',2,'MarkerSize',30);
plot(mean(serialRecallData{PdMRSecondTrialIndex,correctColumnIndex}),'.--','Color',[0.6 0.6 0.6],'LineWidth',1,'MarkerSize',20);
xticks(1:6);
axis([0.9 6.1 0 1]);
xlabel('Serial Position')
ylabel('Correct Response Rate');
set(gca,'FontSize',FONT_SIZE);
set(gcf,'PaperUnits','inches','PaperPosition',[0 0 FIGURE_WIDTH/2 FIGURE_HEIGHT-2]);
outputFileName = ['.\Figures\Serial Position Curves for Similar Lists Split by Condition Order'];
print(outputFileName,'-dpng','-r600');


for(positionIndex = 1:6);
	PoMRFirstTrialsCorrect = sum(serialRecallData{PoMRFirstTrialIndex,correctColumnIndex(positionIndex)});
	PoMRFirstTrialsIncorrect = sum(PoMRFirstTrialIndex) - PoMRFirstTrialsCorrect;
	PoMRSecondTrialsCorrect = sum(serialRecallData{PoMRSecondTrialIndex,correctColumnIndex(positionIndex)});
	PoMRSecondTrialsIncorrect = sum(PoMRSecondTrialIndex) - PoMRSecondTrialsCorrect;
	[~,veridicalSPCfisherP(positionIndex)] =  fishertest([PoMRFirstTrialsCorrect, PoMRFirstTrialsIncorrect;...
							PoMRSecondTrialsCorrect, PoMRSecondTrialsIncorrect]);
end
disp('********************************************************************************');
disp('Serial Position Curve Difference Tests for Condition Order, Veridical Lists')
disp(num2str(veridicalSPCfisherP));
disp(['Significant values are < ' num2str(0.05/6) ' after Bonferroni correction']);

for(positionIndex = 1:6);
	PdMRFirstTrialsCorrect = sum(serialRecallData{PdMRFirstTrialIndex,correctColumnIndex(positionIndex)});
	PdMRFirstTrialsIncorrect = sum(PdMRFirstTrialIndex) - PdMRFirstTrialsCorrect;
	PdMRSecondTrialsCorrect = sum(serialRecallData{PdMRSecondTrialIndex,correctColumnIndex(positionIndex)});
	PdMRSecondTrialsIncorrect = sum(PdMRSecondTrialIndex) - PdMRSecondTrialsCorrect;
	[~,spuriousSPCfisherP(positionIndex)] =  fishertest([PdMRFirstTrialsCorrect, PdMRFirstTrialsIncorrect;...
							PdMRSecondTrialsCorrect, PdMRSecondTrialsIncorrect]);
end
disp('********************************************************************************');
disp('Serial Position Curve Difference Tests for Condition Order, Spurious Lists')
disp(num2str(spuriousSPCfisherP));
disp(['Significant values are < ' num2str(0.05/6) ' after Bonferroni correction']);

