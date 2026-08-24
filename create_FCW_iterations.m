%% ============================================================
% FCW - Automatisation des tests depuis Excel
% MATLAB R2022b / Simulink Test
%
% Excel
%   -> 20 Parameter Sets
%   -> 20 Test Iterations
%   -> FCW_Harness
%   -> Test Assessment
%% ============================================================

clear;
clc;

%% ============================================================
% 1. CONFIGURATION
%% ============================================================

projectFolder = ...
    'C:\Users\HP\Documents\FCW_ADAS';

excelFile = fullfile( ...
    projectFolder, ...
    'FCW_TestCases_20_Industrial.xlsx');

testFilePath = fullfile( ...
    projectFolder, ...
    'FCW_Validation.mldatx');

cd(projectFolder);

fprintf('\n');
fprintf('============================================\n');
fprintf(' FCW AUTOMATED TEST GENERATION\n');
fprintf('============================================\n');

%% ============================================================
% 2. LIRE EXCEL
%% ============================================================

Cases = readtable(excelFile);

N = height(Cases);

fprintf('Nombre de cas Excel : %d\n', N);

if N == 0
    error('Le fichier Excel ne contient aucun cas de test.');
end

%% ============================================================
% 3. CREER LES VARIABLES DE REFERENCE DANS BASE WORKSPACE
%
% Elles permettent a Test Manager / Test Sequence /
% Test Assessment de connaitre les 7 parametres.
%% ============================================================

assignin('base','tc_distance',0);
assignin('base','tc_vrel',0);
assignin('base','tc_targetPresent',0);
assignin('base','tc_targetInLane',0);

assignin('base','tc_expectedSafe',0);
assignin('base','tc_expectedYellow',0);
assignin('base','tc_expectedRed',0);

fprintf('7 variables creees dans base workspace.\n');

%% ============================================================
% 4. CHARGER TEST MANAGER
%% ============================================================

tf = sltest.testmanager.load(testFilePath);

%% ============================================================
% 5. RECUPERER TEST SUITE
%% ============================================================

testSuites = getTestSuites(tf);

if isempty(testSuites)
    error('Aucun Test Suite trouve.');
end

% Chercher FCW_Functional_Tests
ts = [];

for k = 1:numel(testSuites)
    if strcmp(testSuites(k).Name,'FCW_Functional_Tests')
        ts = testSuites(k);
        break;
    end
end

if isempty(ts)
    % fallback
    ts = testSuites(1);
end

fprintf('Test Suite : %s\n', ts.Name);

%% ============================================================
% 6. RECUPERER TEST CASE
%% ============================================================

testCases = getTestCases(ts);

if isempty(testCases)
    error('Aucun Test Case trouve.');
end

tc = [];

for k = 1:numel(testCases)
    if strcmp(testCases(k).Name,'FCW_Automated_Test')
        tc = testCases(k);
        break;
    end
end

if isempty(tc)
    % fallback
    tc = testCases(1);
end

fprintf('Test Case  : %s\n', tc.Name);

%% ============================================================
% 7. SUPPRIMER LES ANCIENNES ITERATIONS
%% ============================================================

oldIterations = getIterations(tc);

if ~isempty(oldIterations)

    deleteIterations(tc, oldIterations);

    fprintf( ...
        'Anciennes iterations supprimees : %d\n', ...
        numel(oldIterations));

end

%% ============================================================
% 8. SUPPRIMER LES ANCIENS PARAMETER SETS
%
% Cela supprimera aussi Parameter Set 1 cree manuellement.
%% ============================================================

oldParameterSets = getParameterSets(tc);

if ~isempty(oldParameterSets)

    fprintf( ...
        'Suppression de %d ancien(s) Parameter Set(s)...\n', ...
        numel(oldParameterSets));

    for k = numel(oldParameterSets):-1:1
        remove(oldParameterSets(k));
    end

end

%% ============================================================
% 9. GENERER LES 20 PARAMETER SETS + ITERATIONS
%% ============================================================

for i = 1:N

    %% --------------------------------------------------------
    % A. Recuperer Test ID
    %% --------------------------------------------------------

    if iscell(Cases.TestID)

        testID = Cases.TestID{i};

    elseif isstring(Cases.TestID)

        testID = char(Cases.TestID(i));

    else

        testID = char(string(Cases.TestID(i)));

    end

    %% --------------------------------------------------------
    % B. Recuperer les 4 ENTREES
    %% --------------------------------------------------------

    distance = ...
        Cases.DistanceRelative_m(i);

    vrel = ...
        Cases.VitesseRelative_mps(i);

    targetPresent = ...
        Cases.TargetPresent(i);

    targetInLane = ...
        Cases.TargetInLane(i);

    %% --------------------------------------------------------
    % C. Recuperer les 3 RESULTATS ATTENDUS
    %% --------------------------------------------------------

    expectedSafe = ...
        Cases.Expected_SAFE(i);

    expectedYellow = ...
        Cases.Expected_YELLOWWARNING(i);

    expectedRed = ...
        Cases.Expected_REDWARNING(i);

    %% --------------------------------------------------------
    % D. Creer le Parameter Set
    %% --------------------------------------------------------

    psName = ...
        ['PS_' testID];

    ps = addParameterSet( ...
        tc, ...
        'Name', psName);

    %% --------------------------------------------------------
    % E. Ajouter les 7 Parameter Overrides
    %
    % Ces noms correspondent aux variables que Test Manager
    % a deja detectees dans base workspace / FCW_Harness.
    %% --------------------------------------------------------

    addParameterOverride( ...
        ps, ...
        'tc_distance', ...
        distance);

    addParameterOverride( ...
        ps, ...
        'tc_vrel', ...
        vrel);

    addParameterOverride( ...
        ps, ...
        'tc_targetPresent', ...
        targetPresent);

    addParameterOverride( ...
        ps, ...
        'tc_targetInLane', ...
        targetInLane);

    addParameterOverride( ...
        ps, ...
        'tc_expectedSafe', ...
        expectedSafe);

    addParameterOverride( ...
        ps, ...
        'tc_expectedYellow', ...
        expectedYellow);

    addParameterOverride( ...
        ps, ...
        'tc_expectedRed', ...
        expectedRed);

    %% --------------------------------------------------------
    % F. Creer une Test Iteration
    %% --------------------------------------------------------

    iter = sltest.testmanager.TestIteration;

    %% Associer cette iteration a son Parameter Set
    setTestParam( ...
        iter, ...
        'ParameterSet', ...
        psName);

    %% Ajouter iteration au Test Case
    addIteration( ...
        tc, ...
        iter, ...
        testID);

    %% --------------------------------------------------------
    % G. Afficher les valeurs
    %% --------------------------------------------------------

    fprintf( ...
        ['%s -> %s | ' ...
         'D=%.3f | Vrel=%.3f | ' ...
         'Present=%d | Lane=%d | ' ...
         'Expected=[S:%d Y:%d R:%d]\n'], ...
        testID, ...
        psName, ...
        distance, ...
        vrel, ...
        targetPresent, ...
        targetInLane, ...
        expectedSafe, ...
        expectedYellow, ...
        expectedRed);

end

%% ============================================================
% 10. SAUVEGARDER TEST MANAGER
%% ============================================================

saveToFile(tf);

fprintf('\n');
fprintf('============================================\n');
fprintf(' GENERATION TERMINEE\n');
fprintf('============================================\n');

%% ============================================================
% 11. VERIFICATION AUTOMATIQUE
%% ============================================================

parameterSets = getParameterSets(tc);
iterations   = getIterations(tc);

fprintf( ...
    'Parameter Sets : %d\n', ...
    numel(parameterSets));

fprintf( ...
    'Iterations     : %d\n', ...
    numel(iterations));

if numel(parameterSets) ~= N

    warning( ...
        'Attendu %d Parameter Sets mais %d trouves.', ...
        N, ...
        numel(parameterSets));

end

if numel(iterations) ~= N

    warning( ...
        'Attendu %d iterations mais %d trouvees.', ...
        N, ...
        numel(iterations));

end

%% ============================================================
% 12. AFFICHER UN EXEMPLE DE CONTROLE : FCW_012
%% ============================================================

if N >= 12

    fprintf('\n');
    fprintf('Verification FCW_012 :\n');

    fprintf( ...
        'Distance       = %.3f\n', ...
        Cases.DistanceRelative_m(12));

    fprintf( ...
        'Vrel           = %.3f\n', ...
        Cases.VitesseRelative_mps(12));

    fprintf( ...
        'TargetPresent  = %d\n', ...
        Cases.TargetPresent(12));

    fprintf( ...
        'TargetInLane   = %d\n', ...
        Cases.TargetInLane(12));

    fprintf( ...
        'Expected SAFE  = %d\n', ...
        Cases.Expected_SAFE(12));

    fprintf( ...
        'Expected YELLOW= %d\n', ...
        Cases.Expected_YELLOWWARNING(12));

    fprintf( ...
        'Expected RED   = %d\n', ...
        Cases.Expected_REDWARNING(12));

end

%% ============================================================
% 13. OUVRIR TEST MANAGER
%% ============================================================

sltest.testmanager.view;

fprintf('\n');
fprintf('Test Manager ouvert.\n');
fprintf('NE PAS lancer les 20 tests tout de suite.\n');
fprintf('Tester FCW_012 seul en premier.\n');