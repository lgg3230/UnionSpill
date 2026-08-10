
%% Clear Workspace
clear; clc; close all;
%% Define the available years (adjust as needed)
start_year = 2009;
end_year   = 2012;

%% Load the treatment status dataset (treatment data)
% This file (treat_cnpj.csv) contains two columns:
%   - identificad: Unique employer ID (as in all your datasets)
%   - treat_ultra: Dummy variable (1 if the employer is treated, 0 otherwise)
treatData = readtable("/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/treat_cnpj.csv");
% Convert the employer IDs to strings for consistent matching
treatData.identificad = string(treatData.identificad);


%% Initialize a cell array to store connectivity tables for each pair
connTables = {};

%% Nested loop: For each starting year y and every later year nextYear
for y = start_year:(end_year - 1)
    for nextYear = (y+1):end_year
        
       
        
        %read 
        mergedData = readtable('/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/employers_%d_%d.csv',y, nextYear);
        
        % Optionally, order variables so that you have:
        % PIS, identificad_y, and identificad_nextYear.
        % (Assume the variables in flowData1 and flowData2 are named 'identificad_y' and 'identificad_nextYear'.)
        % Adjust accordingly if needed.
        
        % --- Build the connectivity measures from mergedData ---
        % For each merged record, you have the employer for year y (source) and nextYear (destination).
        % You would then (as in your existing MATLAB code) form the unique employer mapping,
        % build a sparse adjacency matrix M, and then compute the connectivity measure.
        %
        % [Your existing MATLAB connectivity code goes here, but now using the mergedData from the current pair.
        %  Be sure to dynamically extract the employer IDs based on y and nextYear, and then compute:
        %    - totalOut (or totalIn),
        %    - raw flows to/from treated firms,
        %    - and then the connectivity percentage as
        %      100 * ((outflow to treated + inflow from treated) / (total outflow + total inflow)).
        % ]
        %
        % For illustration, here is a skeletal outline:
        %
        % Extract employer IDs from the merged data:
        %   Assume flowData1 has variable 'identificad_y' and flowData2 has 'identificad_nextYear'
        emp_y = string(mergedData.(['identificad_' num2str(y)]));
        emp_next = string(mergedData.(['identificad_' num2str(nextYear)]));
        
        % Build unique employer mapping from the merged flow data:
        unique_emps = unique([emp_y; emp_next]);
        nEmps = length(unique_emps);
        
        [~, emp_y_idx] = ismember(emp_y, unique_emps);
        [~, emp_next_idx] = ismember(emp_next, unique_emps);
        
        % Remove any rows with invalid indices
        valid_idx = (emp_y_idx > 0) & (emp_next_idx > 0);
        emp_y_idx = emp_y_idx(valid_idx);
        emp_next_idx = emp_next_idx(valid_idx);
        
        % Construct the adjacency matrix: M(i,j) counts worker flows from employer i (year y) to employer j (year nextYear)
        M = sparse(emp_y_idx, emp_next_idx, 1, nEmps, nEmps);
        
        % Load your treatment dataset (if not already loaded outside the loop) and assign treatment status,
        % then compute raw flows (both inflows and outflows) and the connectivity percentage.
        % (See your earlier MATLAB code for details.)
        %
        % For example:
        % [Assume treatData is already loaded and has variables 'identificad' and 'treat_ultra']
        [~, treat_idx] = ismember(unique_emps, treatData.identificad);
        isTreated = zeros(nEmps, 1);
        isTreated(treat_idx > 0) = treatData.treat_ultra(treat_idx(treat_idx > 0));
        
        % Compute total outflows and inflows:
        totalOut = full(sum(M, 2));
        totalIn = full(sum(M, 1))';
        totalFlows = totalOut + totalIn;
        
        % Compute raw flows to/from treated employers:
        outToTreated = full(sum(M(:, isTreated == 1), 2));
        inFromTreated = full(sum(M(isTreated == 1, :), 1))';
        treatedFlows = outToTreated + inFromTreated;
        
        % Compute connectivity percentage:
        connectivityPercentage = 100 * (treatedFlows ./ totalFlows);
        connectivityPercentage(totalFlows == 0) = NaN;
        
        % Create a table for this year pair; always name the employer ID column "identificad"
        T_pair = table(unique_emps, connectivityPercentage, outToTreated, inFromTreated, ...
            'VariableNames', {'identificad', 'Connectivity_Percentage', 'OutflowTreated', 'InflowTreated'});
        
        % Rename the measure variables to include the year pair information
        connVarName = sprintf('Connectivity_%d_%d', y, nextYear);
        outVarName  = sprintf('OutflowTreated_%d_%d', y, nextYear);
        inVarName   = sprintf('InflowTreated_%d_%d', y, nextYear);
        
        T_pair.Properties.VariableNames{'Connectivity_Percentage'} = connVarName;
        T_pair.Properties.VariableNames{'OutflowTreated'} = outVarName;
        T_pair.Properties.VariableNames{'InflowTreated'} = inVarName;
        
        % Store this table
        connTables{end+1} = T_pair;
        
        fprintf('Processed connectivity measures for year pair %d-%d.\n', y, nextYear);
    end
end

% After processing all pairs, merge the connectivity tables on "identificad"
finalTable = connTables{1};
for k = 2:length(connTables)
    finalTable = outerjoin(finalTable, connTables{k}, 'MergeKeys', true, 'Type', 'full');
end

% (Optional) Sort the final table by identificad
finalTable = sortrows(finalTable, 'identificad');

% Finally, merge the treatment dataset (treat_cnpj) onto the final connectivity table.
% This will add a dummy variable indicating whether the employer is treated.
mergedTable = outerjoin(finalTable, treatData, 'MergeKeys', true, 'Type', 'full');
% If any missing treatment status should be assumed 0, then:
missingTreat = isnan(mergedTable.treat_ultra);
mergedTable.treat_ultra(missingTreat) = 0;

% Save the final connectivity dataset as "connectivity_2009_2012.csv"
outputFile = '/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/connectivity_2009_2012.csv';
writetable(mergedTable, outputFile);

disp('Final merged connectivity dataset (for all pairs) with treatment dummy has been saved as connectivity_2009_2012.csv.');
