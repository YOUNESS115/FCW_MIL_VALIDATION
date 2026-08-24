clear;
clc;

fprintf('\n============================================\n');
fprintf(' FCW MIL AUTOMATED REGRESSION\n');
fprintf('============================================\n');

projectFolder = fileparts(mfilename('fullpath'));
cd(projectFolder);

testFile = fullfile(projectFolder, 'FCW_Validation.mldatx');

reportFolder = fullfile(projectFolder, 'reports');

if ~exist(reportFolder, 'dir')
    mkdir(reportFolder);
end

reportFile = fullfile(reportFolder, 'FCW_Test_Report.zip');

%% Nettoyer anciens résultats Test Manager
sltest.testmanager.clearResults;

%% Charger le fichier de tests
fprintf('Loading Test Manager file...\n');
sltest.testmanager.load(testFile);

%% Exécuter toute la campagne
fprintf('Running FCW regression campaign...\n');

results = sltest.testmanager.run;

fprintf('Execution completed.\n');

%% Générer rapport HTML ZIP
fprintf('Generating HTML report...\n');

sltest.testmanager.report( ...
    results, ...
    reportFile, ...
    'IncludeTestResults', 0, ...
    'IncludeErrorMessages', true, ...
    'IncludeMLVersion', true, ...
    'LaunchReport', false);

fprintf('\nReport generated:\n%s\n', reportFile);

fprintf('\n============================================\n');
fprintf(' FCW VALIDATION FINISHED\n');
fprintf('============================================\n');