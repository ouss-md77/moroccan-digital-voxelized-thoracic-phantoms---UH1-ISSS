```matlab
clc;
clear;
close all;

%% ============================================================
% Lung Volume Calculation from Voxelized Labelmaps
%
% Project: Moroccan Digital Voxelized Thoracic Phantoms
% Author: Oussama Aabi
%
% Description:
% This script calculates lung volume from NRRD labelmaps using label 1,
% which corresponds to the lungs.
%
% Groups:
%   H = Male
%   F = Female
%   E = Child
%
% Formula:
%   Lung volume = number of voxels with label 1 × voxel volume
%
% Outputs:
%   - Excel file containing lung volume results for all patients
%   - Excel file containing group statistics
%   - Figures showing lung volume variation
%
% Note:
% The user is asked to select the project folder at runtime.
%% ============================================================

%% ===================== PROJECT FOLDER SELECTION =====================

projectFolder = uigetdir(pwd, 'Select the project folder');

if projectFolder == 0
    error('No project folder selected.');
end

excelFile = fullfile(projectFolder, 'data', 'spacing_patients.xlsx');

tablesFolder = fullfile(projectFolder, 'results', 'tables');
figuresFolder = fullfile(projectFolder, 'results', 'figures');

if ~exist(tablesFolder, 'dir')
    mkdir(tablesFolder);
end

if ~exist(figuresFolder, 'dir')
    mkdir(figuresFolder);
end

if ~isfile(excelFile)
    error('Excel file not found: %s', excelFile);
end

if exist('nrrdread', 'file') ~= 2
    error('The function nrrdread was not found. Please add an NRRD reader to the MATLAB path.');
end

%% ===================== PARAMETERS =====================

lungLabel = 1;

groups = struct();

groups(1).code = 'H';
groups(1).name = 'Male';
groups(1).sheet = 'Homme';
groups(1).patientFolder = 'patient_H';
groups(1).labelFolder = 'labelmaps_H';

groups(2).code = 'F';
groups(2).name = 'Female';
groups(2).sheet = 'Femme';
groups(2).sheetAlt = 'Femmes';
groups(2).patientFolder = 'patient_F';
groups(2).labelFolder = 'labelmaps_F';

groups(3).code = 'E';
groups(3).name = 'Child';
groups(3).sheet = 'Enfant';
groups(3).patientFolder = 'patient_E';
groups(3).labelFolder = 'labelmaps_E';

allResults = table();

%% ===================== LUNG VOLUME CALCULATION =====================

for g = 1:numel(groups)

    groupCode = groups(g).code;
    groupName = groups(g).name;

    patientFolder = fullfile(projectFolder, groups(g).patientFolder);
    labelmapFolder = fullfile(patientFolder, groups(g).labelFolder);

    if ~exist(labelmapFolder, 'dir')
        error('Labelmap folder not found: %s', labelmapFolder);
    end

    sheetName = groups(g).sheet;

    try
        spacingTable = readtable(excelFile, 'Sheet', sheetName, 'VariableNamingRule', 'preserve');
    catch
        if isfield(groups(g), 'sheetAlt')
            sheetName = groups(g).sheetAlt;
            spacingTable = readtable(excelFile, 'Sheet', sheetName, 'VariableNamingRule', 'preserve');
        else
            error('Unable to read Excel sheet: %s', groups(g).sheet);
        end
    end

    requiredColumns = {'patient', 'file_nrrd', 'spacing_x', 'spacing_y', 'spacing_z'};

    for c = 1:numel(requiredColumns)
        if ~ismember(requiredColumns{c}, spacingTable.Properties.VariableNames)
            error('Missing column in sheet %s: %s', sheetName, requiredColumns{c});
        end
    end

    fprintf('\n===== Group: %s | Excel sheet: %s =====\n', groupName, sheetName);

    for i = 1:10

        patientName = sprintf('%s%d', groupCode, i);

        patientIndex = strcmpi(string(spacingTable.patient), patientName);

        if ~any(patientIndex)
            warning('Patient %s not found in Excel file. Skipping.', patientName);
            continue;
        end

        labelmapFile = string(spacingTable.file_nrrd(patientIndex));

        spacingX = spacingTable.spacing_x(patientIndex);
        spacingY = spacingTable.spacing_y(patientIndex);
        spacingZ = spacingTable.spacing_z(patientIndex);

        voxelVolume_mm3 = spacingX * spacingY * spacingZ;

        nrrdPath = fullfile(labelmapFolder, labelmapFile);

        if ~isfile(nrrdPath)
            nrrdPath = fullfile(labelmapFolder, [patientName '.nrrd']);
        end

        if ~isfile(nrrdPath)
            files = dir(fullfile(patientFolder, '**', [patientName '.nrrd']));
            if ~isempty(files)
                nrrdPath = fullfile(files(1).folder, files(1).name);
            else
                warning('NRRD file not found for patient %s. Skipping.', patientName);
                continue;
            end
        end

        labelmapVolume = nrrdread(nrrdPath);
        labelmapVolume = squeeze(labelmapVolume);

        lungMask = (labelmapVolume == lungLabel);

        numberOfVoxels = nnz(lungMask);

        volume_mm3 = numberOfVoxels * voxelVolume_mm3;
        volume_cm3 = volume_mm3 / 1000;
        volume_L = volume_cm3 / 1000;

        fprintf('%s | Voxels = %d | Volume = %.2f cm3 = %.3f L\n', ...
            patientName, numberOfVoxels, volume_cm3, volume_L);

        tempResult = table( ...
            string(patientName), string(groupName), string(groupCode), ...
            string(nrrdPath), ...
            spacingX, spacingY, spacingZ, ...
            voxelVolume_mm3, ...
            numberOfVoxels, ...
            volume_mm3, volume_cm3, volume_L, ...
            'VariableNames', {'Patient', 'Group', 'Group_Code', 'NRRD_File', ...
            'Spacing_X_mm', 'Spacing_Y_mm', 'Spacing_Z_mm', ...
            'Voxel_Volume_mm3', ...
            'Number_Of_Voxels_Label1', ...
            'Lung_Volume_mm3', 'Lung_Volume_cm3', 'Lung_Volume_L'});

        allResults = [allResults; tempResult];
    end
end

if isempty(allResults)
    error('No results were calculated. Please check the Excel file, NRRD files, and labels.');
end

%% ===================== PATIENT ORDERING =====================

orderedPatients = strings(0, 1);

for i = 1:10
    orderedPatients(end + 1, 1) = "H" + string(i);
    orderedPatients(end + 1, 1) = "F" + string(i);
    orderedPatients(end + 1, 1) = "E" + string(i);
end

allResults.Order_Index = zeros(height(allResults), 1);

for r = 1:height(allResults)
    orderIndex = find(strcmpi(orderedPatients, allResults.Patient(r)), 1);
    if ~isempty(orderIndex)
        allResults.Order_Index(r) = orderIndex;
    else
        allResults.Order_Index(r) = 999;
    end
end

allResults = sortrows(allResults, 'Order_Index');

%% ===================== SAVE EXCEL RESULTS =====================

outputExcel = fullfile(tablesFolder, 'lung_volumes_label1_all_patients.xlsx');
writetable(allResults, outputExcel, 'Sheet', 'Lung_Volumes');

fprintf('\nExcel results saved:\n%s\n', outputExcel);

%% ===================== GROUP STATISTICS =====================

groupStatistics = groupsummary(allResults, 'Group', {'mean', 'std', 'min', 'max'}, 'Lung_Volume_cm3');

outputExcelStats = fullfile(tablesFolder, 'lung_volume_group_statistics.xlsx');
writetable(groupStatistics, outputExcelStats, 'Sheet', 'Group_Statistics');

fprintf('Group statistics saved:\n%s\n', outputExcelStats);

%% ===================== VOLUME CURVE IN CM3 =====================

fig1 = figure('Color', 'w', 'Name', 'Lung volume variation in cm3');
hold on;

xAll = 1:height(allResults);

idxH = strcmp(allResults.Group_Code, "H");
idxF = strcmp(allResults.Group_Code, "F");
idxE = strcmp(allResults.Group_Code, "E");

plot(xAll(idxH), allResults.Lung_Volume_cm3(idxH), '-o', ...
    'LineWidth', 2, 'MarkerSize', 7);

plot(xAll(idxF), allResults.Lung_Volume_cm3(idxF), '-s', ...
    'LineWidth', 2, 'MarkerSize', 7);

plot(xAll(idxE), allResults.Lung_Volume_cm3(idxE), '-^', ...
    'LineWidth', 2, 'MarkerSize', 7);

grid on;
box on;

xlabel('Patients');
ylabel('Lung volume label 1 (cm^3)');
title('Lung Volume Variation - H1 F1 E1 ... H10 F10 E10');

xticks(xAll);
xticklabels(allResults.Patient);
xtickangle(45);

legend({'Male', 'Female', 'Child'}, 'Location', 'best');

saveas(fig1, fullfile(figuresFolder, 'lung_volume_variation_cm3.png'));
savefig(fig1, fullfile(figuresFolder, 'lung_volume_variation_cm3.fig'));

%% ===================== VOLUME CURVE IN LITERS =====================

fig2 = figure('Color', 'w', 'Name', 'Lung volume variation in liters');
hold on;

plot(xAll(idxH), allResults.Lung_Volume_L(idxH), '-o', ...
    'LineWidth', 2, 'MarkerSize', 7);

plot(xAll(idxF), allResults.Lung_Volume_L(idxF), '-s', ...
    'LineWidth', 2, 'MarkerSize', 7);

plot(xAll(idxE), allResults.Lung_Volume_L(idxE), '-^', ...
    'LineWidth', 2, 'MarkerSize', 7);

grid on;
box on;

xlabel('Patients');
ylabel('Lung volume label 1 (L)');
title('Lung Volume Variation in Liters - H1 F1 E1 ... H10 F10 E10');

xticks(xAll);
xticklabels(allResults.Patient);
xtickangle(45);

legend({'Male', 'Female', 'Child'}, 'Location', 'best');

saveas(fig2, fullfile(figuresFolder, 'lung_volume_variation_liters.png'));
savefig(fig2, fullfile(figuresFolder, 'lung_volume_variation_liters.fig'));

%% ===================== BAR PLOT =====================

fig3 = figure('Color', 'w', 'Name', 'Lung volume bar plot');

bar(allResults.Lung_Volume_cm3);

grid on;
box on;

xlabel('Patients');
ylabel('Lung volume label 1 (cm^3)');
title('Lung Volumes for All Patients');

xticks(xAll);
xticklabels(allResults.Patient);
xtickangle(45);

saveas(fig3, fullfile(figuresFolder, 'lung_volume_barplot.png'));
savefig(fig3, fullfile(figuresFolder, 'lung_volume_barplot.fig'));

fprintf('\n===== Processing completed successfully =====\n');
fprintf('Tables saved in:\n%s\n', tablesFolder);
fprintf('Figures saved in:\n%s\n', figuresFolder);
```
