```matlab
clc;
clear;
close all;

%% ============================================================
% Labelmap Spacing and Volume Summary
%
% Project: Moroccan Digital Voxelized Thoracic Phantoms
% Author: Oussama Aabi
%
% Description:
% This script reads NRRD labelmaps, extracts voxel spacing from the NRRD
% header, detects anatomical labels, counts voxels, and calculates volumes.
%
% The script is intended for local use only. Patient CT images and NRRD
% labelmaps should not be uploaded to GitHub.
%
% Outputs:
%   - Excel summary in data/
%   - Excel volume table in results/tables/
%   - PNG figures in results/figures/
%
% Expected labels:
%   Male and child:
%       1 = Lungs
%       2 = Body
%       3 = Bones
%
%   Female:
%       1 = Lungs
%       2 = Body
%       3 = Breasts
%       4 = Bones
%% ============================================================

%% ===================== PROJECT FOLDER SELECTION =====================

projectFolder = uigetdir(pwd, 'Select the project folder');

if projectFolder == 0
    error('No project folder selected.');
end

labelmapFolder = uigetdir(projectFolder, 'Select the folder containing NRRD labelmaps');

if labelmapFolder == 0
    error('No labelmap folder selected.');
end

answer = inputdlg( ...
    {'Enter group code (H, F, or E):'}, ...
    'Group information', ...
    [1 50], ...
    {'H'});

if isempty(answer)
    error('No group code entered.');
end

groupCode = upper(strtrim(answer{1}));

if ~ismember(groupCode, {'H', 'F', 'E'})
    error('Invalid group code. Use H, F, or E.');
end

switch groupCode
    case 'H'
        groupName = 'Male';
        expectedLabels = [1 2 3];
        expectedStructures = {'Lungs', 'Body', 'Bones'};
    case 'F'
        groupName = 'Female';
        expectedLabels = [1 2 3 4];
        expectedStructures = {'Lungs', 'Body', 'Breasts', 'Bones'};
    case 'E'
        groupName = 'Child';
        expectedLabels = [1 2 3];
        expectedStructures = {'Lungs', 'Body', 'Bones'};
end

dataFolder = fullfile(projectFolder, 'data');
tablesFolder = fullfile(projectFolder, 'results', 'tables');
figuresFolder = fullfile(projectFolder, 'results', 'figures');

if ~exist(dataFolder, 'dir')
    mkdir(dataFolder);
end

if ~exist(tablesFolder, 'dir')
    mkdir(tablesFolder);
end

if ~exist(figuresFolder, 'dir')
    mkdir(figuresFolder);
end

if exist('nrrdread', 'file') ~= 2
    error('The function nrrdread was not found. Please add an NRRD reader to the MATLAB path.');
end

%% ===================== NRRD FILE SEARCH =====================

nrrdFiles = dir(fullfile(labelmapFolder, '*.nrrd'));

if isempty(nrrdFiles)
    error('No NRRD files found in the selected folder.');
end

mainResults = table();
labelResults = table();

%% ===================== PROCESS LABELMAPS =====================

for i = 1:numel(nrrdFiles)

    nrrdPath = fullfile(nrrdFiles(i).folder, nrrdFiles(i).name);
    fileName = string(nrrdFiles(i).name);

    patientID = inferPatientID(fileName, groupCode, i);

    fprintf('\nReading labelmap: %s\n', fileName);

    [spacing, headerSizes] = readNrrdSpacingAndSizes(nrrdPath);

    labelmap = nrrdread(nrrdPath);
    labelmap = squeeze(labelmap);

    imageSize = size(labelmap);

    if numel(imageSize) == 2
        imageSize(3) = 1;
    end

    spacingX = spacing(1);
    spacingY = spacing(2);
    spacingZ = spacing(3);

    voxelVolume_mm3 = spacingX * spacingY * spacingZ;

    labelsPresent = unique(labelmap(:));
    labelsPresent = labelsPresent(labelsPresent > 0);

    labelsText = strjoin(string(labelsPresent(:)'), ', ');

    fprintf('Patient: %s\n', patientID);
    fprintf('Spacing: %.6f x %.6f x %.6f mm\n', spacingX, spacingY, spacingZ);
    fprintf('Image size: %d x %d x %d voxels\n', imageSize(1), imageSize(2), imageSize(3));
    fprintf('Detected labels: %s\n', labelsText);

    lungVoxels = NaN;
    bodyVoxels = NaN;
    bonesVoxels = NaN;
    breastsVoxels = NaN;

    lungVolume_cm3 = NaN;
    bodyVolume_cm3 = NaN;
    bonesVolume_cm3 = NaN;
    breastsVolume_cm3 = NaN;

    for k = 1:numel(labelsPresent)

        currentLabel = labelsPresent(k);
        numberOfVoxels = nnz(labelmap == currentLabel);

        volume_mm3 = numberOfVoxels * voxelVolume_mm3;
        volume_cm3 = volume_mm3 / 1000;

        structureName = getStructureName(currentLabel, groupCode);

        tempLabel = table( ...
            string(patientID), string(groupName), string(groupCode), ...
            string(fileName), currentLabel, string(structureName), ...
            spacingX, spacingY, spacingZ, voxelVolume_mm3, ...
            imageSize(1), imageSize(2), imageSize(3), ...
            numberOfVoxels, volume_mm3, volume_cm3, ...
            'VariableNames', {'Patient', 'Group', 'Group_Code', ...
            'File_NRRD', 'Label', 'Structure', ...
            'Spacing_X_mm', 'Spacing_Y_mm', 'Spacing_Z_mm', 'Voxel_Volume_mm3', ...
            'Size_X', 'Size_Y', 'Size_Z', ...
            'Number_Of_Voxels', 'Volume_mm3', 'Volume_cm3'});

        labelResults = [labelResults; tempLabel];

        if currentLabel == 1
            lungVoxels = numberOfVoxels;
            lungVolume_cm3 = volume_cm3;
        elseif currentLabel == 2
            bodyVoxels = numberOfVoxels;
            bodyVolume_cm3 = volume_cm3;
        elseif currentLabel == 3 && groupCode == "F"
            breastsVoxels = numberOfVoxels;
            breastsVolume_cm3 = volume_cm3;
        elseif currentLabel == 3 && groupCode ~= "F"
            bonesVoxels = numberOfVoxels;
            bonesVolume_cm3 = volume_cm3;
        elseif currentLabel == 4 && groupCode == "F"
            bonesVoxels = numberOfVoxels;
            bonesVolume_cm3 = volume_cm3;
        end
    end

    missingLabels = setdiff(expectedLabels, labelsPresent);

    if isempty(missingLabels)
        missingLabelsText = "None";
    else
        missingLabelsText = strjoin(string(missingLabels), ', ');
    end

    tempMain = table( ...
        string(patientID), string(groupName), string(groupCode), string(fileName), ...
        spacingX, spacingY, spacingZ, voxelVolume_mm3, ...
        imageSize(1), imageSize(2), imageSize(3), ...
        headerSizes(1), headerSizes(2), headerSizes(3), ...
        string(labelsText), string(missingLabelsText), ...
        lungVoxels, lungVolume_cm3, ...
        bodyVoxels, bodyVolume_cm3, ...
        breastsVoxels, breastsVolume_cm3, ...
        bonesVoxels, bonesVolume_cm3, ...
        'VariableNames', {'Patient', 'Group', 'Group_Code', 'File_NRRD', ...
        'Spacing_X_mm', 'Spacing_Y_mm', 'Spacing_Z_mm', 'Voxel_Volume_mm3', ...
        'Size_X', 'Size_Y', 'Size_Z', ...
        'Header_Size_X', 'Header_Size_Y', 'Header_Size_Z', ...
        'Detected_Labels', 'Missing_Expected_Labels', ...
        'Lung_Voxels', 'Lung_Volume_cm3', ...
        'Body_Voxels', 'Body_Volume_cm3', ...
        'Breast_Voxels', 'Breast_Volume_cm3', ...
        'Bone_Voxels', 'Bone_Volume_cm3'});

    mainResults = [mainResults; tempMain];
end

%% ===================== SORT RESULTS =====================

mainResults.Patient_Order = zeros(height(mainResults), 1);

for r = 1:height(mainResults)
    numberToken = regexp(mainResults.Patient(r), '\d+', 'match', 'once');
    if isempty(numberToken)
        mainResults.Patient_Order(r) = r;
    else
        mainResults.Patient_Order(r) = str2double(numberToken);
    end
end

mainResults = sortrows(mainResults, 'Patient_Order');
labelResults = sortrows(labelResults, {'Patient', 'Label'});

%% ===================== GROUP STATISTICS =====================

validLungVolumes = mainResults.Lung_Volume_cm3(~isnan(mainResults.Lung_Volume_cm3));

if isempty(validLungVolumes)
    warning('No lung volume values were calculated.');
    statsResults = table();
else
    meanLungVolume_cm3 = mean(validLungVolumes);
    stdLungVolume_cm3 = std(validLungVolumes);
    medianLungVolume_cm3 = median(validLungVolumes);
    minLungVolume_cm3 = min(validLungVolumes);
    maxLungVolume_cm3 = max(validLungVolumes);

    distanceToMean_cm3 = abs(mainResults.Lung_Volume_cm3 - meanLungVolume_cm3);
    mainResults.Distance_To_Mean_Lung_Volume_cm3 = distanceToMean_cm3;

    [minimumDistance, closestIndex] = min(distanceToMean_cm3);

    statsResults = table( ...
        string(groupName), string(groupCode), ...
        meanLungVolume_cm3, stdLungVolume_cm3, medianLungVolume_cm3, ...
        minLungVolume_cm3, maxLungVolume_cm3, ...
        string(mainResults.Patient(closestIndex)), ...
        mainResults.Lung_Volume_cm3(closestIndex), ...
        minimumDistance, ...
        'VariableNames', {'Group', 'Group_Code', ...
        'Mean_Lung_Volume_cm3', 'Std_Lung_Volume_cm3', 'Median_Lung_Volume_cm3', ...
        'Min_Lung_Volume_cm3', 'Max_Lung_Volume_cm3', ...
        'Patient_Closest_To_Mean', 'Closest_Patient_Lung_Volume_cm3', ...
        'Difference_From_Mean_cm3'});
end

mainResults = sortrows(mainResults, 'Patient_Order');

%% ===================== SAVE EXCEL FILES =====================

summaryExcel = fullfile(dataFolder, lower(groupCode) + "_labelmap_spacing_summary.xlsx");
volumeExcel = fullfile(tablesFolder, lower(groupCode) + "_labelmap_volume_summary.xlsx");

writetable(mainResults, summaryExcel, 'Sheet', 'Spacing_Summary');

writetable(labelResults, volumeExcel, 'Sheet', 'Label_Volumes');

if ~isempty(statsResults)
    writetable(statsResults, volumeExcel, 'Sheet', 'Lung_Stats');
    writetable(sortrows(mainResults, 'Distance_To_Mean_Lung_Volume_cm3'), ...
        volumeExcel, 'Sheet', 'Closest_To_Mean');
end

fprintf('\nSpacing summary saved in:\n%s\n', summaryExcel);
fprintf('Volume summary saved in:\n%s\n', volumeExcel);

%% ===================== FIGURES =====================

if any(~isnan(mainResults.Lung_Volume_cm3))

    x = 1:height(mainResults);

    fig1 = figure('Color', 'w', 'Name', 'Lung volume per patient');
    bar(mainResults.Lung_Volume_cm3);
    hold on;

    if ~isempty(validLungVolumes)
        yline(meanLungVolume_cm3, '--', 'Mean', 'LineWidth', 2);
        plot(closestIndex, mainResults.Lung_Volume_cm3(closestIndex), ...
            'o', 'MarkerSize', 12, 'LineWidth', 3);
    end

    hold off;
    grid on;
    box on;

    xticks(x);
    xticklabels(mainResults.Patient);
    xlabel('Patients');
    ylabel('Lung volume (cm^3)');
    title(['Lung Volumes - ', groupName]);

    saveas(fig1, fullfile(figuresFolder, lower(groupCode) + "_lung_volume_barplot.png"));
    savefig(fig1, fullfile(figuresFolder, lower(groupCode) + "_lung_volume_barplot.fig"));

    fig2 = figure('Color', 'w', 'Name', 'Lung volume curve');
    plot(x, mainResults.Lung_Volume_cm3, '-o', 'LineWidth', 2, 'MarkerSize', 7);
    hold on;

    if ~isempty(validLungVolumes)
        yline(meanLungVolume_cm3, '--', 'Mean', 'LineWidth', 2);
        plot(closestIndex, mainResults.Lung_Volume_cm3(closestIndex), ...
            'o', 'MarkerSize', 12, 'LineWidth', 3);
    end

    hold off;
    grid on;
    box on;

    xticks(x);
    xticklabels(mainResults.Patient);
    xlabel('Patients');
    ylabel('Lung volume (cm^3)');
    title(['Lung Volume Curve - ', groupName]);

    saveas(fig2, fullfile(figuresFolder, lower(groupCode) + "_lung_volume_curve.png"));
    savefig(fig2, fullfile(figuresFolder, lower(groupCode) + "_lung_volume_curve.fig"));

    if ismember('Distance_To_Mean_Lung_Volume_cm3', mainResults.Properties.VariableNames)

        fig3 = figure('Color', 'w', 'Name', 'Distance to mean lung volume');
        bar(mainResults.Distance_To_Mean_Lung_Volume_cm3);

        grid on;
        box on;

        xticks(x);
        xticklabels(mainResults.Patient);
        xlabel('Patients');
        ylabel('Distance to mean lung volume (cm^3)');
        title(['Distance to Mean Lung Volume - ', groupName]);

        saveas(fig3, fullfile(figuresFolder, lower(groupCode) + "_lung_volume_distance_to_mean.png"));
        savefig(fig3, fullfile(figuresFolder, lower(groupCode) + "_lung_volume_distance_to_mean.fig"));
    end

    if any(~isnan(mainResults.Body_Volume_cm3))

        fig4 = figure('Color', 'w', 'Name', 'Lungs and body volume comparison');
        bar([mainResults.Lung_Volume_cm3 mainResults.Body_Volume_cm3]);

        grid on;
        box on;

        xticks(x);
        xticklabels(mainResults.Patient);
        xlabel('Patients');
        ylabel('Volume (cm^3)');
        title(['Lung and Body Volume Comparison - ', groupName]);
        legend({'Lungs', 'Body'}, 'Location', 'best');

        saveas(fig4, fullfile(figuresFolder, lower(groupCode) + "_lung_body_volume_comparison.png"));
        savefig(fig4, fullfile(figuresFolder, lower(groupCode) + "_lung_body_volume_comparison.fig"));
    end
end

fprintf('\n===== Processing completed successfully =====\n');
fprintf('Data saved in:\n%s\n', dataFolder);
fprintf('Tables saved in:\n%s\n', tablesFolder);
fprintf('Figures saved in:\n%s\n', figuresFolder);

%% ===================== LOCAL FUNCTIONS =====================

function patientID = inferPatientID(fileName, groupCode, index)

    fileName = char(fileName);

    expression = [groupCode, '\d+'];
    token = regexp(fileName, expression, 'match', 'once');

    if isempty(token)
        [~, baseName, ~] = fileparts(fileName);
        token = baseName;

        if isempty(token)
            token = sprintf('%s%d', groupCode, index);
        end
    end

    patientID = string(token);
end

function structureName = getStructureName(labelValue, groupCode)

    if groupCode == "F"
        switch labelValue
            case 1
                structureName = 'Lungs';
            case 2
                structureName = 'Body';
            case 3
                structureName = 'Breasts';
            case 4
                structureName = 'Bones';
            otherwise
                structureName = 'Unknown';
        end
    else
        switch labelValue
            case 1
                structureName = 'Lungs';
            case 2
                structureName = 'Body';
            case 3
                structureName = 'Bones';
            otherwise
                structureName = 'Unknown';
        end
    end
end

function [spacing, sizes] = readNrrdSpacingAndSizes(nrrdPath)

    spacing = [NaN NaN NaN];
    sizes = [NaN NaN NaN];

    fid = fopen(nrrdPath, 'r');

    if fid == -1
        warning('Unable to open NRRD file header: %s', nrrdPath);
        return;
    end

    headerLines = {};

    while true
        line = fgetl(fid);

        if ~ischar(line)
            break;
        end

        headerLines{end + 1} = line;

        if isempty(strtrim(line))
            break;
        end
    end

    fclose(fid);

    for i = 1:numel(headerLines)

        line = strtrim(headerLines{i});

        if startsWith(lower(line), 'space directions:')
            value = strtrim(extractAfter(line, ':'));
            parts = regexp(value, '\([^\)]*\)|none', 'match');

            directions = [];

            for p = 1:numel(parts)

                currentPart = strtrim(parts{p});

                if strcmpi(currentPart, 'none')
                    continue;
                end

                numbers = regexp(currentPart, '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', 'match');
                numbers = str2double(numbers);

                if ~isempty(numbers)
                    directions(end + 1) = norm(numbers);
                end
            end

            if numel(directions) >= 3
                spacing = directions(1:3);
            end
        end

        if startsWith(lower(line), 'spacings:') && any(isnan(spacing))
            value = strtrim(extractAfter(line, ':'));
            numbers = regexp(value, '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?', 'match');
            numbers = str2double(numbers);

            if numel(numbers) >= 3
                spacing = numbers(1:3);
            end
        end

        if startsWith(lower(line), 'sizes:')
            value = strtrim(extractAfter(line, ':'));
            numbers = regexp(value, '\d+', 'match');
            numbers = str2double(numbers);

            if numel(numbers) >= 3
                sizes = numbers(1:3);
            end
        end
    end
end
```
