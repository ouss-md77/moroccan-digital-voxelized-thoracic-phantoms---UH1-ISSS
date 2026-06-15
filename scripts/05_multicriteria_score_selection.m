```matlab
clc;
clear;
close all;

%% ============================================================
% Multicriteria Representative Phantom Selection
%
% Project: Moroccan Digital Voxelized Thoracic Phantoms
% Author: Oussama Aabi
%
% Description:
% This script selects the most representative thoracic voxelized phantom
% for a selected group using a multicriteria score.
%
% Criteria:
%   1. Lung volume proximity to the group mean
%   2. Chest Wall Thickness proximity to a reference value
%   3. Anteroposterior Diameter proximity to the group mean
%
% Score:
%   Lower score = better representative phantom
%
% Required input tables:
%   - Lung volume results
%   - CWT results
%   - DAP results
%
% Outputs:
%   - Excel file in results/tables/selection/
%   - Figures in results/figures/selection/
%
% Important:
% Only anonymized patient IDs such as H1, F1, and E1 should be used.
%% ============================================================

%% ===================== PROJECT FOLDER SELECTION =====================

projectFolder = uigetdir(pwd, 'Select the project folder');

if projectFolder == 0
    error('No project folder selected.');
end

tablesFolder = fullfile(projectFolder, 'results', 'tables', 'selection');
figuresFolder = fullfile(projectFolder, 'results', 'figures', 'selection');

if ~exist(tablesFolder, 'dir')
    mkdir(tablesFolder);
end

if ~exist(figuresFolder, 'dir')
    mkdir(figuresFolder);
end

%% ===================== GROUP SELECTION =====================

fprintf('\n===== GROUP SELECTION =====\n');
fprintf('H : Male\n');
fprintf('F : Female\n');
fprintf('E : Child\n');

groupCode = upper(strtrim(input('Select the group for representative phantom selection (H/F/E): ', 's')));

if ~ismember(groupCode, {'H','F','E'})
    error('Invalid group. Please select only H, F, or E.');
end

switch groupCode
    case 'H'
        groupName = 'Male';
        referenceCWT_mm = 28.7;
        referenceCWTDescription = 'Vickers adult male reference';

    case 'F'
        groupName = 'Female';
        referenceCWT_mm = 29.4;
        referenceCWTDescription = 'Vickers adult female reference';

    case 'E'
        groupName = 'Child';
        referenceCWT_mm = NaN;
        referenceCWTDescription = 'Group mean used because no pediatric reference was available';
end

%% ===================== FILE SELECTION =====================

defaultVolumeFile = fullfile(projectFolder, 'results', 'tables', 'lung_volumes_label1_all_patients.xlsx');
defaultCWTFile = fullfile(projectFolder, 'results', 'tables', 'cwt_results.xlsx');
defaultDAPFile = fullfile(projectFolder, 'results', 'tables', 'dap_results.xlsx');

volumeFile = getFileOrAsk(defaultVolumeFile, 'Select lung volume results Excel file');
cwtFile = getFileOrAsk(defaultCWTFile, 'Select CWT results Excel file');
dapFile = getFileOrAsk(defaultDAPFile, 'Select DAP results Excel file');

fprintf('\nVolume file: %s\n', volumeFile);
fprintf('CWT file: %s\n', cwtFile);
fprintf('DAP file: %s\n', dapFile);

%% ===================== READ INPUT TABLES =====================

volumeTable = readBestSheet(volumeFile, {'Lung_Volumes','Volumes','Patient_Summary','Resume_Patients','Sheet1'});
cwtTable = readBestSheet(cwtFile, {'Patient_Summary','Summary','Resume','Resume_Patients','Score_Final','Sheet1'});
dapTable = readBestSheet(dapFile, {'Patient_Summary','Summary','Slice_Details','Resume_Patients','Sheet1'});

%% ===================== EXTRACT PATIENT DATA =====================

volumeData = extractPatientValues(volumeTable, ...
    {'Patient','patient','id_patients','id_patient'}, ...
    {'Lung_Volume_cm3','Volume_Poumons_cm3','volume_poumons_cm3','Volume_cm3'}, ...
    'Lung_Volume_cm3');

cwtData = extractPatientValues(cwtTable, ...
    {'Patient','patient','id_patients','id_patient'}, ...
    {'Mean_CWT_mm','CWT_Moyenne_mm','cwt_moyenne_mm', ...
     'CWT_Posterieur_Moyenne_mm','Mean_Directional_Thickness_mm', ...
     'Mean_CWT_Patient_mm','CWT_mm'}, ...
    'CWT_mm');

dapData = extractPatientValues(dapTable, ...
    {'Patient','patient','id_patients','id_patient'}, ...
    {'Mean_DAP_mm','DAP_moyen_patient_mm','DAP_moyen_mm', ...
     'Mean_DAP_Patient_mm','DAP_mm'}, ...
    'DAP_mm');

%% ===================== MERGE DATA =====================

data = innerjoin(volumeData, cwtData, 'Keys', 'Patient');
data = innerjoin(data, dapData, 'Keys', 'Patient');

if isempty(data)
    error('No common patients were found between volume, CWT, and DAP tables.');
end

data.Patient = string(data.Patient);

groupMask = startsWith(upper(data.Patient), groupCode);
data = data(groupMask, :);

if isempty(data)
    error('No patients found for group %s.', groupCode);
end

data.Patient_Order = getPatientOrder(data.Patient);
data = sortrows(data, 'Patient_Order');

%% ===================== REFERENCE VALUES =====================

lungVolumeMean_cm3 = mean(data.Lung_Volume_cm3, 'omitnan');
dapMean_mm = mean(data.DAP_mm, 'omitnan');

if isnan(referenceCWT_mm)
    referenceCWT_mm = mean(data.CWT_mm, 'omitnan');
end

if lungVolumeMean_cm3 == 0 || isnan(lungVolumeMean_cm3)
    error('Invalid lung volume mean.');
end

if referenceCWT_mm == 0 || isnan(referenceCWT_mm)
    error('Invalid CWT reference value.');
end

if dapMean_mm == 0 || isnan(dapMean_mm)
    error('Invalid DAP mean value.');
end

%% ===================== SCORE PARAMETERS =====================

weightVolume = 1/3;
weightCWT = 1/3;
weightDAP = 1/3;

%% ===================== SCORE CALCULATION =====================

data.Distance_To_Volume_Mean_cm3 = abs(data.Lung_Volume_cm3 - lungVolumeMean_cm3);
data.Distance_To_CWT_Reference_mm = abs(data.CWT_mm - referenceCWT_mm);
data.Distance_To_DAP_Mean_mm = abs(data.DAP_mm - dapMean_mm);

data.Score_Volume = data.Distance_To_Volume_Mean_cm3 / lungVolumeMean_cm3;
data.Score_CWT = data.Distance_To_CWT_Reference_mm / referenceCWT_mm;
data.Score_DAP = data.Distance_To_DAP_Mean_mm / dapMean_mm;

data.Score_Total = ...
    weightVolume * data.Score_Volume + ...
    weightCWT * data.Score_CWT + ...
    weightDAP * data.Score_DAP;

data = sortrows(data, 'Score_Total', 'ascend');

%% ===================== FINAL SELECTION =====================

selectedPatient = data.Patient(1);
selectedVolume = data.Lung_Volume_cm3(1);
selectedCWT = data.CWT_mm(1);
selectedDAP = data.DAP_mm(1);
selectedScore = data.Score_Total(1);

[~, idxClosestVolume] = min(data.Distance_To_Volume_Mean_cm3);
[~, idxClosestCWT] = min(data.Distance_To_CWT_Reference_mm);
[~, idxClosestDAP] = min(data.Distance_To_DAP_Mean_mm);

patientClosestVolume = data.Patient(idxClosestVolume);
patientClosestCWT = data.Patient(idxClosestCWT);
patientClosestDAP = data.Patient(idxClosestDAP);

%% ===================== STATISTICS TABLE =====================

statisticsTable = table( ...
    string(groupName), string(groupCode), ...
    lungVolumeMean_cm3, ...
    referenceCWT_mm, string(referenceCWTDescription), ...
    dapMean_mm, ...
    weightVolume, weightCWT, weightDAP, ...
    patientClosestVolume, patientClosestCWT, patientClosestDAP, ...
    selectedPatient, selectedVolume, selectedCWT, selectedDAP, selectedScore, ...
    'VariableNames', {'Group','Group_Code', ...
    'Mean_Lung_Volume_cm3', ...
    'Reference_CWT_mm','Reference_CWT_Description', ...
    'Mean_DAP_mm', ...
    'Weight_Volume','Weight_CWT','Weight_DAP', ...
    'Patient_Closest_To_Volume_Mean', ...
    'Patient_Closest_To_CWT_Reference', ...
    'Patient_Closest_To_DAP_Mean', ...
    'Selected_Representative_Patient', ...
    'Selected_Lung_Volume_cm3', ...
    'Selected_CWT_mm', ...
    'Selected_DAP_mm', ...
    'Selected_Total_Score'});

%% ===================== DISPLAY RESULTS =====================

disp('================ MULTICRITERIA SCORE RESULTS ================');
disp(data);

disp('================ FINAL STATISTICS ================');
disp(statisticsTable);

fprintf('\n==============================================\n');
fprintf('GROUP: %s\n', groupName);
fprintf('SELECTED REPRESENTATIVE PATIENT: %s\n', selectedPatient);
fprintf('Lung volume = %.2f cm3\n', selectedVolume);
fprintf('CWT = %.2f mm\n', selectedCWT);
fprintf('DAP = %.2f mm\n', selectedDAP);
fprintf('Total score = %.4f\n', selectedScore);
fprintf('==============================================\n');

%% ===================== SAVE EXCEL FILE =====================

outputExcel = fullfile(tablesFolder, lower(groupCode) + "_multicriteria_selection.xlsx");

writetable(data, outputExcel, 'Sheet', 'Multicriteria_Score');
writetable(statisticsTable, outputExcel, 'Sheet', 'Final_Statistics');

fprintf('\nExcel results saved in:\n%s\n', outputExcel);

%% ===================== FIGURES =====================

dataForPlot = sortrows(data, 'Patient_Order');
x = 1:height(dataForPlot);

selectedIndexPlot = find(dataForPlot.Patient == selectedPatient, 1);

%% Figure 1: total score
fig1 = figure('Color','w', 'Name','Total multicriteria score');
bar(dataForPlot.Score_Total);
hold on;
plot(selectedIndexPlot, dataForPlot.Score_Total(selectedIndexPlot), ...
    'o', 'MarkerSize', 12, 'LineWidth', 3);
hold off;

grid on;
box on;
xticks(x);
xticklabels(dataForPlot.Patient);
xlabel('Patients');
ylabel('Total score');
title(['Multicriteria Score - Selected Patient: ', char(selectedPatient)]);

saveas(fig1, fullfile(figuresFolder, lower(groupCode) + "_multicriteria_total_score.png"));
savefig(fig1, fullfile(figuresFolder, lower(groupCode) + "_multicriteria_total_score.fig"));

%% Figure 2: score components
fig2 = figure('Color','w', 'Name','Score components');
bar([dataForPlot.Score_Volume dataForPlot.Score_CWT dataForPlot.Score_DAP dataForPlot.Score_Total]);

grid on;
box on;
xticks(x);
xticklabels(dataForPlot.Patient);
xlabel('Patients');
ylabel('Normalized score');
title(['Score Components - ', groupName]);
legend({'Volume','CWT','DAP','Total'}, 'Location', 'best');

saveas(fig2, fullfile(figuresFolder, lower(groupCode) + "_multicriteria_score_components.png"));
savefig(fig2, fullfile(figuresFolder, lower(groupCode) + "_multicriteria_score_components.fig"));

%% Figure 3: lung volume
fig3 = figure('Color','w', 'Name','Lung volume comparison');
bar(dataForPlot.Lung_Volume_cm3);
hold on;
yline(lungVolumeMean_cm3, '--', 'Group mean', 'LineWidth', 2);
plot(find(dataForPlot.Patient == patientClosestVolume, 1), ...
    dataForPlot.Lung_Volume_cm3(dataForPlot.Patient == patientClosestVolume), ...
    'o', 'MarkerSize', 12, 'LineWidth', 3);
hold off;

grid on;
box on;
xticks(x);
xticklabels(dataForPlot.Patient);
xlabel('Patients');
ylabel('Lung volume (cm^3)');
title(['Lung Volume Comparison - ', groupName]);

saveas(fig3, fullfile(figuresFolder, lower(groupCode) + "_lung_volume_vs_mean.png"));
savefig(fig3, fullfile(figuresFolder, lower(groupCode) + "_lung_volume_vs_mean.fig"));

%% Figure 4: CWT
fig4 = figure('Color','w', 'Name','CWT comparison');
bar(dataForPlot.CWT_mm);
hold on;
yline(referenceCWT_mm, '-.', 'Reference CWT', 'LineWidth', 2);
plot(find(dataForPlot.Patient == patientClosestCWT, 1), ...
    dataForPlot.CWT_mm(dataForPlot.Patient == patientClosestCWT), ...
    'o', 'MarkerSize', 12, 'LineWidth', 3);
hold off;

grid on;
box on;
xticks(x);
xticklabels(dataForPlot.Patient);
xlabel('Patients');
ylabel('CWT (mm)');
title(['CWT Comparison - ', groupName]);

saveas(fig4, fullfile(figuresFolder, lower(groupCode) + "_cwt_vs_reference.png"));
savefig(fig4, fullfile(figuresFolder, lower(groupCode) + "_cwt_vs_reference.fig"));

%% Figure 5: DAP
fig5 = figure('Color','w', 'Name','DAP comparison');
bar(dataForPlot.DAP_mm);
hold on;
yline(dapMean_mm, '--', 'Group mean DAP', 'LineWidth', 2);
plot(find(dataForPlot.Patient == patientClosestDAP, 1), ...
    dataForPlot.DAP_mm(dataForPlot.Patient == patientClosestDAP), ...
    'o', 'MarkerSize', 12, 'LineWidth', 3);
hold off;

grid on;
box on;
xticks(x);
xticklabels(dataForPlot.Patient);
xlabel('Patients');
ylabel('DAP (mm)');
title(['DAP Comparison - ', groupName]);

saveas(fig5, fullfile(figuresFolder, lower(groupCode) + "_dap_vs_mean.png"));
savefig(fig5, fullfile(figuresFolder, lower(groupCode) + "_dap_vs_mean.fig"));

%% Figure 6: volume-CWT scatter
fig6 = figure('Color','w', 'Name','Volume CWT scatter');
scatter(dataForPlot.Lung_Volume_cm3, dataForPlot.CWT_mm, 80, 'filled');
hold on;
xline(lungVolumeMean_cm3, '--', 'Volume mean', 'LineWidth', 2);
yline(referenceCWT_mm, '-.', 'CWT reference', 'LineWidth', 2);
plot(selectedVolume, selectedCWT, 'o', 'MarkerSize', 14, 'LineWidth', 3);

for i = 1:height(dataForPlot)
    text(dataForPlot.Lung_Volume_cm3(i), dataForPlot.CWT_mm(i), ...
        ['  ', char(dataForPlot.Patient(i))], ...
        'FontSize', 10, 'FontWeight', 'bold');
end

hold off;
grid on;
box on;
xlabel('Lung volume (cm^3)');
ylabel('CWT (mm)');
title(['Volume-CWT Position - Selected Patient: ', char(selectedPatient)]);

saveas(fig6, fullfile(figuresFolder, lower(groupCode) + "_volume_cwt_scatter.png"));
savefig(fig6, fullfile(figuresFolder, lower(groupCode) + "_volume_cwt_scatter.fig"));

fprintf('\nFigures saved in:\n%s\n', figuresFolder);
fprintf('\n===== Processing completed successfully =====\n');

%% ============================================================
% LOCAL FUNCTIONS
%% ============================================================

function filePath = getFileOrAsk(defaultPath, dialogTitle)

    if isfile(defaultPath)
        filePath = defaultPath;
        return;
    end

    [fileName, folderName] = uigetfile({'*.xlsx;*.xls','Excel Files (*.xlsx, *.xls)'}, dialogTitle);

    if isequal(fileName, 0)
        error('No Excel file selected.');
    end

    filePath = fullfile(folderName, fileName);
end

function outputTable = readBestSheet(filePath, candidateSheets)

    availableSheets = sheetnames(filePath);

    selectedSheet = "";

    for i = 1:numel(candidateSheets)
        if any(strcmpi(availableSheets, candidateSheets{i}))
            selectedSheet = candidateSheets{i};
            break;
        end
    end

    if selectedSheet == ""
        selectedSheet = availableSheets(1);
    end

    outputTable = readtable(filePath, 'Sheet', selectedSheet, 'VariableNamingRule', 'preserve');

    fprintf('Reading sheet "%s" from file:\n%s\n', selectedSheet, filePath);
end

function outputData = extractPatientValues(inputTable, patientColumnNames, valueColumnNames, outputValueName)

    patientColumn = getExistingColumn(inputTable, patientColumnNames);
    valueColumn = getExistingColumn(inputTable, valueColumnNames);

    patientIDs = string(inputTable.(patientColumn));
    values = inputTable.(valueColumn);

    validRows = ~ismissing(patientIDs) & ~isnan(values);

    patientIDs = patientIDs(validRows);
    values = values(validRows);

    [uniquePatients, ~, groupIndex] = unique(patientIDs, 'stable');

    meanValues = splitapply(@(x) mean(x, 'omitnan'), values, groupIndex);

    outputData = table(uniquePatients, meanValues, ...
        'VariableNames', {'Patient', outputValueName});
end

function columnName = getExistingColumn(inputTable, possibleNames)

    columnName = "";

    for i = 1:numel(possibleNames)
        if ismember(possibleNames{i}, inputTable.Properties.VariableNames)
            columnName = possibleNames{i};
            return;
        end
    end

    error('None of the required columns was found: %s', strjoin(possibleNames, ', '));
end

function orderValues = getPatientOrder(patientIDs)

    orderValues = zeros(numel(patientIDs), 1);

    for i = 1:numel(patientIDs)
        token = regexp(char(patientIDs(i)), '\d+', 'match', 'once');

        if isempty(token)
            orderValues(i) = i;
        else
            orderValues(i) = str2double(token);
        end
    end
end
```
