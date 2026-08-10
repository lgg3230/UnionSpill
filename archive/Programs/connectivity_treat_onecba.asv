%%file Cle()ar Workspace
clear; clc; close all;

%% Define the available years (adjust as needed)
start_year = 2007;
end_year   = 2011;

%% Load Lagos Sample Dataset
% load dataset with dummny defining lagos sample
onecbatreat = readtable("/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/one_cba_treat.csv");
% convert employer id to string:
onecbatreat.identificad = string(onecbatreat.identificad);

%% initialize cell to store connectivity measures
conntables = {};

%% defining y and next for testing:
%y = start_year;
%next_y = (y+1);

%% Loop: compute connectivity matrix and sum flows to lagos sample for every two consecutive years:

for y = start_year:(end_year-1)
        next_y = (y+1);
        
        %ead employers across two consecutive years datasets:
        filename = sprintf('/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/employers_%d_%d.csv', y, next_y);
        employers = readtable(filename);
        %employers = readtable("/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/employers_2007_2008.csv");
        
        % Extract establishment id from employers data:
        estab_y = string(employers.(['identificad_' num2str(y)]));
        estab_next = string(employers.(['identificad_' num2str(next_y)]));
        
        % build unique estab mapping: gives unique estabs in each year
        unique_estabs = unique([estab_y; estab_next]);
        n_estabs = length(unique_estabs);
        
        % Map each employer ID to its index in unique_emps.
        [~, estab_y_idx] = ismember(estab_y, unique_estabs);
        [~, estab_next_idx] = ismember(estab_next, unique_estabs);
        
        % Remove invalid rows:
        valid_idx = (estab_y_idx > 0) & (estab_next_idx > 0);
        estab_y_idx = estab_y_idx(valid_idx);
        estab_next_idx = estab_next_idx(valid_idx);
        
        % Construct adjecency matrix for establishments, zeros main diagonal
        
        M_estabs = sparse(estab_y_idx, estab_next_idx, 1, n_estabs, n_estabs);
        M_estabs(1:n_estabs+1:end) = 0;
        
        % Mark which estabs are part of Lagos sample:
        
        [~, one_idx] = ismember(unique_estabs, onecbatreat.identificad);
        is_one = zeros(n_estabs,1);
        is_one(one_idx > 0) = onecbatreat.one_cba_treat(one_idx(one_idx > 0));

        
        
        % Compute flows between establishments
        
        totalOut = full(sum(M_estabs, 2));
        totalIn = full(sum(M_estabs, 1))';
        totalFlows = totalOut + totalIn;
        
        outToOne = full(sum(M_estabs(:, is_one == 1), 2));
        inFromOne = full(sum(M_estabs(is_one == 1, :), 1))';
        OneFlows = outToOne + inFromOne;
        
        % Load employment data for both years
        emp_y    = employers.(['firm_emp_' num2str(y)]);
        emp_next = employers.(['firm_emp_' num2str(next_y)]);

        % Map employment to unique establishments
        emp_y_mapped    = zeros(n_estabs, 1);
        emp_next_mapped = zeros(n_estabs, 1);

        [found_y, idx_y] = ismember(estab_y, unique_estabs);
        emp_y_mapped(idx_y(found_y)) = emp_y(found_y);

        [found_next, idx_next] = ismember(estab_next, unique_estabs);
        emp_next_mapped(idx_next(found_next)) = emp_next(found_next);

        % Compute average employment and avoid division by zero
        avg_emp = (emp_y_mapped + emp_next_mapped) / 2;
        avg_emp(avg_emp == 0) = NaN;

        % Normalize flows as a ratio of the number of workers
        norm_totalOut   = totalOut ./ avg_emp;
        norm_totalIn    = totalIn  ./ avg_emp;
        norm_totalFlows = totalFlows ./ avg_emp;

        norm_outToOne = outToOne ./ avg_emp;
        norm_inFromOne = inFromOne ./ avg_emp;
        norm_OneFlows = OneFlows ./ avg_emp;
        
        % Normalize flows as a ratio of total flows
        
        norm_OneFlows_pf = OneFlows ./ totalFlows;
        
        % Put together measures in order to generate tables for each 2 consecutive years
        T_pair = table(unique_estabs, ...
                    totalOut, totalIn, totalFlows, ...
                    norm_totalOut, norm_totalIn, norm_totalFlows, ...
                    outToOne, inFromOne, OneFlows, ...
                    norm_outToOne, norm_inFromOne, norm_OneFlows, ...
                    norm_OneFlows_pf, ...
                    'VariableNames', { ...
                        'identificad1', ...
                        'total_out','total_in','total_flows', ...
                        'total_out_pw','total_in_pw','total_flows_pw', ...
                        'out_one','in_one','one_flows', ...
                        'out_one_pw','in_one_pw','one_flows_pw', 'one_flows_pf' ...
                    });
       
       
        % rename varibles to include years
        
        outVarName   = sprintf('totalout_%d_%d', y, next_y);
        inVarName    = sprintf('totalin_%d_%d', y, next_y);
        connVarName  = sprintf('totalflows_%d_%d', y, next_y);
        outtlVarName = sprintf('outone_%d_%d',y,next_y);
        inftlVarName = sprintf('inone_%d_%d', y, next_y);
        totlVarName  = sprintf('totalone_%d_%d',y,next_y);
        
        T_pair.Properties.VariableNames{'total_flows'} = connVarName;
        T_pair.Properties.VariableNames{'total_out'} = outVarName;
        T_pair.Properties.VariableNames{'total_in'} = inVarName;
        T_pair.Properties.VariableNames{'out_one'} = outtlVarName;
        T_pair.Properties.VariableNames{'in_one'} = inftlVarName;
        T_pair.Properties.VariableNames{'one_flows'} = totlVarName;
        
        outVarName_pw   = sprintf('totalout_pw_%d_%d', y, next_y);
        inVarName_pw    = sprintf('totalin_pw_%d_%d', y, next_y);
        connVarName_pw  = sprintf('totalflows_pw_%d_%d', y, next_y);
        outtlVarName_pw = sprintf('outone_pw_%d_%d', y, next_y);
        inftlVarName_pw = sprintf('inone_pw_%d_%d', y, next_y);
        totlVarName_pw  = sprintf('totalone_pw_%d_%d', y, next_y);
        totlVarName_pf  = sprintf('totalone_pf_%d_%d', y, next_y);

        T_pair.Properties.VariableNames{'total_out_pw'}    = outVarName_pw;
        T_pair.Properties.VariableNames{'total_in_pw'}     = inVarName_pw;
        T_pair.Properties.VariableNames{'total_flows_pw'}  = connVarName_pw;
        T_pair.Properties.VariableNames{'out_one_pw'}    = outtlVarName_pw;
        T_pair.Properties.VariableNames{'in_one_pw'}     = inftlVarName_pw;
        T_pair.Properties.VariableNames{'one_flows_pw'}  = totlVarName_pw;
        T_pair.Properties.VariableNames{'one_flows_pf'}  = totlVarName_pf;
        
        % Store this table in our cell array.
        conntables{end+1} = T_pair;
        
        fprintf('Processed connectivity measures for year pair %d-%d.\n', y, next_y);
        
end

%% Merge All Connectivity Tables into One Final Table
% Use an outer join on "identificad" so that every employer is included.
finaltable = conntables{1};
for k = 2:length(conntables)
    finaltable = outerjoin(finaltable, conntables{k}, 'MergeKeys', true, 'Type', 'full');
end

%% (Optional) Sort the final table by identificad.
finaltable = sortrows(finaltable, 'identificad1');
%% Save the Final Merged Connectivity Dataset
outputFile = '/kellogg/proj/lgg3230/UnionSpill/Data/RAIS_aux/connectivity_onecba_2007_2011.csv';  
writetable(finaltable,outputFile);