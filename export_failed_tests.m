%% ============================================================
% FCW - EXPORT AUTOMATIQUE DES TESTS FAILED
%
% Sortie :
%   reports/failed_tests.json
%
% Donnees exportees :
%   - Test ID
%   - Status
%   - Inputs
%   - Expected outputs
%   - Actual outputs
%   - Expected/Actual mismatches
%   - Cause Test Manager
%   - Technical warnings
%
% IMPORTANT :
%   run_FCW_validation doit avoir ete execute avant
%   afin que la variable "results" existe.
%% ============================================================

fprintf('\n============================================\n');
fprintf(' FCW FAILED TEST EXPORT\n');
fprintf('============================================\n');


%% ============================================================
% 1. VERIFIER QUE LES RESULTATS EXISTENT
%% ============================================================

if ~exist('results', 'var')

    error([ ...
        'La variable "results" n''existe pas. ' ...
        'Executer run_FCW_validation avant export_failed_tests.' ...
    ]);

end


%% ============================================================
% 2. RECUPERER LA HIERARCHIE DES RESULTATS TEST MANAGER
%% ============================================================

fprintf('Reading Test Manager results...\n');

tfr = getTestFileResults(results);

if isempty(tfr)
    error('Aucun TestFileResult trouve.');
end

tsr = getTestSuiteResults(tfr(1));

if isempty(tsr)
    error('Aucun TestSuiteResult trouve.');
end

tcr = getTestCaseResults(tsr(1));

if isempty(tcr)
    error('Aucun TestCaseResult trouve.');
end

itr = getIterationResults(tcr(1));

fprintf('Nombre total iterations : %d\n', numel(itr));


%% ============================================================
% 3. PREPARER LA LISTE DES TESTS FAILED
%% ============================================================

failedTests = struct([]);

failIndex = 0;


%% ============================================================
% 4. PARCOURIR TOUTES LES ITERATIONS
%% ============================================================

for i = 1:numel(itr)

    testName = string(itr(i).Name);
    outcome  = string(itr(i).Outcome);

    fprintf('%s -> %s\n', testName, outcome);


    %% --------------------------------------------------------
    % Ne garder que les tests Failed
    %% --------------------------------------------------------

    if ~strcmpi(outcome, "Failed")
        continue;
    end

    failIndex = failIndex + 1;


    %% ========================================================
    % 4.A RECUPERER INPUTS + EXPECTED OUTPUTS
    %% ========================================================

    params = itr(i).ParameterSet.ParameterOverrides;


    % ---------------- INPUTS ----------------

    distance = getParameterValue( ...
        params, ...
        'tc_distance' ...
    );

    vrel = getParameterValue( ...
        params, ...
        'tc_vrel' ...
    );

    targetPresent = getParameterValue( ...
        params, ...
        'tc_targetPresent' ...
    );

    targetInLane = getParameterValue( ...
        params, ...
        'tc_targetInLane' ...
    );


    % ---------------- EXPECTED ----------------

    expectedSafe = getParameterValue( ...
        params, ...
        'tc_expectedSafe' ...
    );

    expectedYellow = getParameterValue( ...
        params, ...
        'tc_expectedYellow' ...
    );

    expectedRed = getParameterValue( ...
        params, ...
        'tc_expectedRed' ...
    );


    %% ========================================================
    % 4.B RECUPERER LES ACTUAL OUTPUTS
    %% ========================================================

    actualSafe   = NaN;
    actualYellow = NaN;
    actualRed    = NaN;

    warningsText = "";


    try

        outputRuns = getOutputRuns(itr(i));

        if ~isempty(outputRuns)

            outputRun = outputRuns(1);

            %% -----------------------------------------------
            % Recuperer les warnings Simulink
            %% -----------------------------------------------

            try
                warningsText = string( ...
                    outputRun.ExecutionWarnings ...
                );
            catch
                warningsText = "";
            end


            %% -----------------------------------------------
            % Recuperer les signaux logges
            %% -----------------------------------------------

            signalIDs = outputRun.getAllSignalIDs;


            for sIndex = 1:numel(signalIDs)

                sig = Simulink.sdi.getSignal( ...
                    signalIDs(sIndex) ...
                );

                signalName = string(sig.Name);

                values = sig.Values;


                %% -------------------------------------------
                % Ignorer les signaux sans donnees
                %% -------------------------------------------

                if isempty(values) || isempty(values.Data)
                    continue;
                end


                %% -------------------------------------------
                % Recuperer la derniere valeur du signal
                %% -------------------------------------------

                signalData = squeeze(values.Data);

                if isempty(signalData)
                    continue;
                end

                finalValue = signalData(end);


                %% -------------------------------------------
                % Mapping des sorties du Subsystem
                %
                % Subsystem:3 -> REDWARNING
                % Subsystem:4 -> YELLOWWARNING
                % Subsystem:5 -> SAFE
                %% -------------------------------------------

                if endsWith(signalName, ":3")

                    actualRed = double(finalValue);


                elseif endsWith(signalName, ":4")

                    actualYellow = double(finalValue);


                elseif endsWith(signalName, ":5")

                    actualSafe = double(finalValue);

                end

            end

        end


    catch ME

        warningsText = warningsText + ...
            " | Actual output extraction error: " + ...
            string(ME.message);

    end


    %% ========================================================
    % 4.C DETECTER LES MISMATCHES EXPECTED / ACTUAL
    %% ========================================================

    mismatches = {};


    if ~isnan(actualSafe)

        if expectedSafe ~= actualSafe

            mismatches{end+1} = sprintf( ...
                'SAFE expected %g actual %g', ...
                expectedSafe, ...
                actualSafe ...
            );

        end

    end


    if ~isnan(actualYellow)

        if expectedYellow ~= actualYellow

            mismatches{end+1} = sprintf( ...
                'YELLOW expected %g actual %g', ...
                expectedYellow, ...
                actualYellow ...
            );

        end

    end


    if ~isnan(actualRed)

        if expectedRed ~= actualRed

            mismatches{end+1} = sprintf( ...
                'RED expected %g actual %g', ...
                expectedRed, ...
                actualRed ...
            );

        end

    end


    %% ========================================================
    % 4.D EXTRAIRE UNIQUEMENT LES WARNINGS TECHNIQUES UTILES
    %% ========================================================

    technicalWarnings = {};


    %% --------------------------------------------------------
    % Division par zero
    %% --------------------------------------------------------

    if contains( ...
            warningsText, ...
            "Division by zero", ...
            'IgnoreCase', true)

        technicalWarnings{end+1} = ...
            'Division by zero in FCW_Harness/Subsystem/Divide1';

    end


    %% --------------------------------------------------------
    % Eventuel probleme de simulation
    %% --------------------------------------------------------

    if contains( ...
            warningsText, ...
            "simulation error", ...
            'IgnoreCase', true)

        technicalWarnings{end+1} = ...
            'Simulation error detected';

    end


    %% --------------------------------------------------------
    % Eventuel probleme de solver
    %% --------------------------------------------------------

    if contains( ...
            warningsText, ...
            "solver", ...
            'IgnoreCase', true)

        technicalWarnings{end+1} = ...
            'Solver-related warning detected';

    end


    %% ========================================================
    % 4.E CONSTRUIRE L'OBJET DU TEST FAILED
    %% ========================================================

    failedTests(failIndex).test_id = ...
        char(testName);

    failedTests(failIndex).status = ...
        char(outcome);


    %% ---------------- INPUTS ----------------

    failedTests(failIndex).inputs.distance = ...
        distance;

    failedTests(failIndex).inputs.vrel = ...
        vrel;

    failedTests(failIndex).inputs.targetPresent = ...
        targetPresent;

    failedTests(failIndex).inputs.targetInLane = ...
        targetInLane;


    %% ---------------- EXPECTED ----------------

    failedTests(failIndex).expected.safe = ...
        expectedSafe;

    failedTests(failIndex).expected.yellow = ...
        expectedYellow;

    failedTests(failIndex).expected.red = ...
        expectedRed;


    %% ---------------- ACTUAL ----------------

    failedTests(failIndex).actual.safe = ...
        actualSafe;

    failedTests(failIndex).actual.yellow = ...
        actualYellow;

    failedTests(failIndex).actual.red = ...
        actualRed;


    %% ---------------- MISMATCHES ----------------

    failedTests(failIndex).mismatches = ...
        mismatches;


    %% ---------------- CAUSE TEST MANAGER ----------------

    failedTests(failIndex).cause_of_failure = ...
        char( ...
            string(itr(i).CauseOfFailure) ...
        );


    %% ---------------- TECHNICAL WARNINGS ----------------

    failedTests(failIndex).technical_warnings = ...
        technicalWarnings;


    %% ========================================================
    % 4.F AFFICHAGE RESUME DU FAIL
    %% ========================================================

    fprintf('\n--------------------------------------------\n');
    fprintf('FAILED TEST : %s\n', testName);

    fprintf( ...
        'Input D=%g | Vrel=%g | Present=%g | Lane=%g\n', ...
        distance, ...
        vrel, ...
        targetPresent, ...
        targetInLane ...
    );

    fprintf( ...
        'Expected : SAFE=%g YELLOW=%g RED=%g\n', ...
        expectedSafe, ...
        expectedYellow, ...
        expectedRed ...
    );

    fprintf( ...
        'Actual   : SAFE=%g YELLOW=%g RED=%g\n', ...
        actualSafe, ...
        actualYellow, ...
        actualRed ...
    );


    if ~isempty(mismatches)

        fprintf('Mismatches:\n');

        for m = 1:numel(mismatches)

            fprintf( ...
                ' - %s\n', ...
                mismatches{m} ...
            );

        end

    end

end


%% ============================================================
% 5. CREER LE DOSSIER REPORTS
%% ============================================================

projectFolder = fileparts( ...
    mfilename('fullpath') ...
);

reportFolder = fullfile( ...
    projectFolder, ...
    'reports' ...
);

if ~exist(reportFolder, 'dir')

    mkdir(reportFolder);

end


jsonFile = fullfile( ...
    reportFolder, ...
    'failed_tests.json' ...
);


%% ============================================================
% 6. GENERER LE JSON
%% ============================================================

if failIndex == 0

    %% Aucun FAIL
    jsonText = '[]';

else

    jsonText = jsonencode( ...
        failedTests ...
    );

end


%% ============================================================
% 7. ECRIRE LE JSON
%% ============================================================

fid = fopen( ...
    jsonFile, ...
    'w' ...
);

if fid == -1

    error( ...
        'Impossible de creer le fichier JSON : %s', ...
        jsonFile ...
    );

end


fprintf( ...
    fid, ...
    '%s', ...
    jsonText ...
);

fclose(fid);


%% ============================================================
% 8. RESUME
%% ============================================================

fprintf('\n============================================\n');
fprintf(' EXPORT TERMINE\n');
fprintf('============================================\n');

fprintf( ...
    'Tests total : %d\n', ...
    numel(itr) ...
);

fprintf( ...
    'Tests FAIL  : %d\n', ...
    failIndex ...
);

fprintf('\nJSON genere :\n');

fprintf( ...
    '%s\n', ...
    jsonFile ...
);


if failIndex == 0

    fprintf('\nAucun test FAIL.\n');
    fprintf('failed_tests.json = []\n');

else

    fprintf( ...
        '\n%d test(s) FAIL exporte(s).\n', ...
        failIndex ...
    );

end


%% ============================================================
% FONCTION UTILITAIRE :
% RECUPERER UNE VALEUR DU PARAMETER SET
%% ============================================================

function value = getParameterValue( ...
    params, ...
    variableName ...
)

    value = NaN;


    for k = 1:numel(params)

        if strcmp( ...
                params(k).Variable, ...
                variableName)

            value = params(k).Value;

            return;

        end

    end

end