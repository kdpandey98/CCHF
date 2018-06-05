% Copyright 2013, 2014, 2015, 2016 Thomas M. Mosier, Kendra V. Sharp, and 
% David F. Hill
% This file is part of multiple packages, including the GlobalClimateData 
% Downscaling Package, the Hydropower Potential Assessment Tool, and the 
% Conceptual Cryosphere Hydrology Framework.
% 
% The above named packages are free software: you can 
% redistribute it and/or modify it under the terms of the GNU General 
% Public License as published by the Free Software Foundation, either 
% version 3 of the License, or (at your option) any later version.
% 
% The above named packages are distributed in the hope that it will be 
% useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
% Public License for more details.
% 
% You should have received a copy of the GNU General Public License
% along with the Downscaling Package.  If not, see 
% <http://www.gnu.org/licenses/>.

function varargout = mod_v_obs_v2(sObs, sMod, methRank, varargin)
%Match all observation data to model output for observations taken at one
%point in time or over a duration (must have fields '.[field]_dateStart' and
%'.[field]_dateStart') and calculate performance statistic.  Currently
%all observations of a same type are lumped together before being compared
%(e.g. if many stake measurements present, these will be lumped together
%before calculating a performance statistic).



flagPlot = 0;
flagScatter = 0;
flagGrid = 0;
typeCombine = '';
flagOneStat = 0;
statCombine = 'linear';
outputPath = '';
rmMod = '';
lon = nan;
lat = nan;
wrtGridTyp = [];
if ~isempty(varargin)
    for ii = 1 : numel(varargin) 
        if ischar(varargin{ii})
            switch varargin{ii}
                case 'rmMod'
                    rmMod = 'rmMod';
                case 'plot'
                    flagPlot = 1;

                    [dirCheck,~,~] = fileparts(varargin{ii+1});
                    if isdir(dirCheck)
                        outputPath = varargin{ii+1};
                    else
                        warning('mod_v_obs:dirOutput',['The argument after '...
                            char(39) 'plot' char(39) ' is not an output '...
                            'directory. Therefore no plots will be written '...
                            'to file. Check input argument order']);
                    end
                case 'combineType'
                    typeCombine = 'type';
                case 'lumpType'
                    typeCombine = 'lump';
                case 'oneStat'
                    flagOneStat = 1;
                case 'square'
                    statCombine = 'square';
                case 'scatter'
                   flagScatter = 1; 
                case 'grid'
                    flagGrid = 1;
                case 'lon'
                    if isnumeric(varargin{ii+1})
                        lon = varargin{ii+1};
                    else
                        error('mod_v_obs:lonNotNum','The optional argument for longitude is non-numeric');
                    end
                case 'lat'
                    if isnumeric(varargin{ii+1})
                        lat = varargin{ii+1};
                    else
                        error('mod_v_obs:latNotNum','The optional argument for latitude is non-numeric');
                    end
                case 'wrtGridTyp'
                    wrtGridTyp = varargin{ii+1};
            end
        end
    end
end

% if flagOneStat && typeCombine
%     typeCombine = 0;
%     warning('mod_v_obs:lump',['Both ' char(39) 'lump by type' char(39) ...
%         ' and ' char(39) 'lump all' char(39) ' were entered. ' char(39)...
%         'lump all' char(39) ' will be used.']);
% end

if flagScatter && ~flagPlot
    flagScatter = 0;
    warning('mod_v_obs:scatterNoPlot','The scatter option is selected but no plot is requested.');
end

ptsObs = fieldnames(sObs);
ptsMod = fieldnames(sMod);

%Variables that may indicate ice change
varMb = {'ice_change', 'mb', 'massbal'};
varGeodetic = 'geodetic';
varStake = 'stake';

%Create output array for observations-model comparisons:
dataAll = cell(0,5);
%Format is: 
    %{ii,1} = {Measurement Type; reference date dateRef; [lon, lat]; eval metric};
    %{ii,2} = dates/days (Model)
    %{ii,3} = data (Model)
    %{ii,4} = days (Obs)
    %{ii,5} = data (Obs)
iMeta = 1;
iMDate = 2;
iMData = 3;
iODate = 4;
iOData = 5;


%%FIND ALL DATA FIELDS PRESENT IN OBSERVATION DATA:
obsTypes = cell(0,1);
%Add all fields in observation data
for ii = 1 : numel(ptsObs(:)) %Loop over all observation points
    fldCurrObs = fieldnames(sObs.(ptsObs{ii}));
    obsTypes(end+1:end+numel(fldCurrObs),1) = fldCurrObs;
end
%Remove all fields dealing with coordinates, time, or attributes:
fieldsRem = {'lat','lon','att','date','time','flag'};
for ii = numel(obsTypes) : -1 : 1
   if regexpbl(obsTypes{ii}, fieldsRem) 
       obsTypes(ii) = [];
   elseif regexpbl(obsTypes{ii}, {'_path', 'path_'})
        obsTypes(ii) = [];
    elseif regexpbl(obsTypes{ii}, {'_type','type_'})
        obsTypes(ii) = [];
   end
end

obsTypes = unique(obsTypes);

    
cntrObs = 0;
%Find matches between observation and model output:
for ii = 1 : numel(ptsObs(:)) %Loop over all points in the Observation data
    indCurr = strcmpi(ptsObs{ii},ptsMod);
    
    if all(indCurr == 0)
        warning('mod_vs_obs:missingField',['Observations at ' ...
            ptsObs{ii} ' are being skipped because output are not '...
            'available in the model output.']);
        continue
    end
        
    
    fldsCurrMod = fieldnames(sMod.(ptsMod{indCurr}));
    fldCurrObs = fieldnames(sObs.(ptsObs{ii}));
        %Remove non-data fields
        fldCurrObs(strcmpi(fldCurrObs,'lat')) = [];
        fldCurrObs(strcmpi(fldCurrObs,'latitude')) = [];
        fldCurrObs(strcmpi(fldCurrObs,'lon')) = [];
        fldCurrObs(strcmpi(fldCurrObs,'longitude')) = [];
        fldCurrObs(strcmpi(fldCurrObs,'att')) = [];
        fldCurrObs(strcmpi(fldCurrObs,'attributes')) = [];
        fldCurrObs(strcmpi(fldCurrObs,'flag')) = [];
        fldCurrObs(strcmpi(fldCurrObs,'date')) = [];
        fldCurrObs(strcmpi(fldCurrObs,'dateStart')) = [];
        fldCurrObs(strcmpi(fldCurrObs,'dateEnd')) = [];
        %remove any field starting with 'path_' in it:
        for mm = numel(fldCurrObs(:)) : -1 : 1
            if regexpbl(fldCurrObs{mm}, {'path_', '_path', 'type_', '_type', '_date', 'date_', '_density', 'density_', 'flag_', '_flag'})
                fldCurrObs(mm) = [];
            end
        end

        
    %Loop over fields in observation data (expected that one
    %modelled output exists for each observation field
    for kk = 1 : numel(fldCurrObs(:))
        cntrObs = cntrObs + 1; 
        
        %Initialize metadata cell array:
        dataAll{cntrObs,iMeta} = cell(4,1);
    
        %Find indices for observation fields:
        indField = [];
        if regexpbl(fldCurrObs{kk}, varStake) %Change in ice at one point (Glacier stake measurement)
            indField = [find(strcmpi(fldsCurrMod, 'icdwe') == 1); ...
                find(strcmpi(fldsCurrMod, 'sndwe') == 1)];
            if numel(indField) < 2
                error('mod_v_obs:stakeFields',['Stake data are '...
                    'being used for model assessment.  '...
                    'Either the snowChange or iceChange '...
                    'fields, which are both required, are not '...
                    'present in the model output.']);
            end
            
            evalType = 'sum';
            intrpType = 'sum';
        elseif regexpbl(fldCurrObs{kk},{'snow','radar'},'and') || regexpbl(fldCurrObs{kk},'swe')
            indField = find(strcmpi(fldsCurrMod, 'swe') == 1);
            
            evalType = 'sum';
            intrpType = 'sum';
        elseif regexpbl(fldCurrObs{kk}, {'casi', 'icx', 'snx', 'sca'}) %Snow cover
            %This is tricky because the data to compare with depends on the
            %metric. If metric is ''Parajka' (following Parajka & Bl�schl,
            %2008), then compare MODIS SCA with modelled SWE. Otherwise,
            %compare observed SCA with modelled SCA.
            indField = find(strcmpi(fldsCurrMod, fldCurrObs{kk}) == 1);

            if isfield(sObs.(ptsObs{ii}),[fldCurrObs{kk} '_type'])
                evalType = sObs.(ptsObs{ii}).([fldCurrObs{kk} '_type']);
            else
                evalType = 'max';
                warning('mod_v_obs:unknownEvalType',['The evaluation '...
                    'type is assumed to be ' evalType ' for aggregating ' ...
                    fldCurrObs{kk} ' observations.']);
            end
            
            intrpType = 'mean';
        elseif regexpbl(fldCurrObs{kk}, varMb) %Ice change (modelled once per year)
            indField = find(strcmpi(fldsCurrMod, 'icmb') == 1);
            evalType = 'sum';
            intrpType = 'sum';
        elseif regexpbl(fldCurrObs{kk}, varGeodetic) %Ice+snow WE change (modelled each time step)
            indField = find(strcmpi(fldsCurrMod, varGeodetic) == 1);
            if isempty(indField)
                indField = [find(strcmpi(fldsCurrMod, 'icdwe') == 1); ...
                    find(strcmpi(fldsCurrMod, 'sndwe') == 1)];
                if numel(indField) < 2
                    error('modVObs:missingGeodeticField', [num2str(numel(indField)) ' of 2 geodetic fields were found using the seperate icdwe and sndwe method.']);
                end
            end
            evalType = 'sum';
            intrpType = 'sum';
        elseif regexpbl(fldCurrObs{kk}, {'flow'}) %streamflow
            indField = find(strcmpi(fldsCurrMod, 'flow') == 1);
            evalType = 'mean';
            intrpType = 'mean';
        elseif regexpbl(fldsCurrMod, fldCurrObs{kk})
            error('modVObs:unknownFieldPresent', ['The gage field ' fldCurrObs{kk} ' is present in the modelled data but has not been programmed for. Please add.']);
        else
            error('modVObs:unknownField', ['The gage field ' fldCurrObs{kk} ' has not been programmed for.']);
        end
        %Throw error if type not found
        if isempty(indField)
           error('modVObs:noIndField', ['The model indice for gage field ' fldCurrObs{kk} ' was not located.']);
        end
        

        fldModDateStrt = [fldsCurrMod{indField(1)} '_dateStart'];
        fldModDateEnd  = [fldsCurrMod{indField(1)}  '_dateEnd'];
        %Retrieve dates and temporal resolution of modelled data:
        if isfield(sMod.(ptsMod{indCurr}), fldModDateStrt) %Start and end dates
            dataAll{cntrObs,iMDate} = cell(2,1);
            dataAll{cntrObs,iMDate}{1} = sMod.(ptsMod{indCurr}).(fldModDateStrt); 
            dataAll{cntrObs,iMDate}{2} = sMod.(ptsMod{indCurr}).(fldModDateEnd);
            tResMod = numel(dataAll{cntrObs,iMDate}{1}(1,:));   
        elseif isfield(sMod.(ptsMod{indCurr}), 'date') %Dates same as model time step
            dataAll{cntrObs,iMDate} = sMod.(ptsMod{indCurr}).date; %Modelled date is always '.date' except mass balance
            tResMod = numel(dataAll{cntrObs,iMDate}(1,:));
        else
            error('modVObs:noDateFieldMod',['No date field has been identified for the model field ' fldsCurrMod{indField(1)} '.']);
        end
        
        
        %Retrieve data from model:
        if ~isempty(indField) %Modelled field exist for current observation field
            if numel(indField) == 2
                dataAll{cntrObs,iMData} = sMod.(ptsMod{indCurr}).(fldsCurrMod{indField(1)}) ...
                        + sMod.(ptsMod{indCurr}).(fldsCurrMod{indField(2)});
            elseif numel(indField) == 1
                dataAll{cntrObs,iMData} = sMod.(ptsMod{indCurr}).(fldsCurrMod{indField});
            end
            
            %SPECIAL TREATMENT FOR STAKE DATA:
%             if regexpbl(nmDataCurrObs{kk},'stake') 
%                 if all(sMod.(namesMod{indCurr}).('iceBl')) == 1
%                     dataAll{cntrObs,indModData} = sMod.(namesMod{indCurr}).(fieldsCurrMod{indField(1)}) ...
%                         + sMod.(namesMod{indCurr}).(fieldsCurrMod{indField(2)});
%                 else
%                     dataAll{cntrObs,indModData} = nan(numel(sMod.(namesMod{indCurr}).(fieldsCurrMod{indField(1)})),1);
%                 end
%             else
%                 dataAll{cntrObs,indModData} = sMod.(namesMod{indCurr}).(fieldsCurrMod{indField});
%             end
        else
            warning('mod_v_obs:missingModOutput',['Field ' fldCurrObs{kk} ...
                ' at observation ' ptsObs{ii} ' is being skipped '...
                'because no modelled indices exist at this point.']);
            continue
        end 

        %Retrieve data from observation:
        if numel(fldCurrObs(kk)) == 1
            dataAll{cntrObs,iOData} = sObs.(ptsObs{ii}).(fldCurrObs{kk});
            
            %If there is a 'flag' field, value of 1 means don't use data in
            %analysis.
            varFlag = [fldCurrObs{kk} '_flag'];
            if isfield(sObs.(ptsObs{ii}), varFlag)
                %Different flag treatment for 3D vs. 2D arrays
                if numel(size(dataAll{cntrObs,iOData})) == 3
                    if numel(sObs.(ptsObs{ii}).(varFlag)) == numel(dataAll{cntrObs,iOData}(:,1,1))
                        for mm = 1 : numel(dataAll{cntrObs,iOData}(:,1,1))
                            if sObs.(ptsObs{ii}).(varFlag)(mm) == 1
                                dataAll{cntrObs,iOData}(mm,:,:) = nan;
                            end
                        end
                    else
                        error('mod_v_obs:error3DFlagSz','The data quality flag has an unexpected size.');
                    end
                elseif numel(size(dataAll{cntrObs,iOData})) == 2
                    if numel(sObs.(ptsObs{ii}).(varFlag)) == numel(dataAll{cntrObs,iOData})
                        dataAll{cntrObs,iOData}(sObs.(ptsObs{ii}).(varFlag) == 1) = nan;
                    else
                        error('mod_v_obs:error2DFlagSz','The data quality flag has an unexpected size.');
                    end
                end
            end
        elseif numel(fldCurrObs(kk)) > 1
            error('mod_v_gage:extraObsFields','Extra data fields exist for current observation variable.');
        else
            error('mod_v_gage:noObsFields','No data fields exist for current observation variable.');
        end

        
        if isfield(sObs.(ptsObs{ii}), [fldCurrObs{kk} '_date']) %Observations occur at single point in time
            dataAll{cntrObs,iODate} = sObs.(ptsObs{ii}).([fldCurrObs{kk} '_date']);
            tResObs = numel(dataAll{cntrObs,iODate}(1,:));

            %If temporal resolution doesn't match, convert (e.g. 
            %if observation data monthly and modelled data daily):
            if tResObs ~= tResMod 
                if tResObs == 3 && tResMod == 2
                    datesAvg = unique(dataAll{cntrObs,iODate}(:,1:2),'rows');
                    dataAvg = nan(numel(datesAvg(:,1)),1);
                    for ll = 1 : numel(datesAvg(:,1))
                        indAvg = ismember(dataAll{cntrObs,iODate}(:,1:2), datesAvg(ll,1:2),'rows');
                        dataAvg(ll) = mean(dataAll{cntrObs,iOData}(indAvg));
                    end

                    dataAll{cntrObs,iOData} =  dataAvg; %Substitute averages for observations
                    dataAll{cntrObs,iODate} = datesAvg;
                elseif tResObs == 2 && tResMod == 3
                    datesAvg = unique(dataAll{cntrObs,iMDate}(:,1:2),'rows');
                    dataAvg = nan(numel(datesAvg(:,1)),1);
                    for ll = 1 : numel(datesAvg(:,1))
                        indAvg = ismember(dataAll{cntrObs,iMDate}(:,1:2), datesAvg(ll,1:2),'rows');
                        dataAvg(ll) = mean(dataAll{cntrObs,iMData}(indAvg));
                    end

                    dataAll{cntrObs,iMData} = dataAvg; %Substitute averages for modelled
                    dataAll{cntrObs,iMDate} = datesAvg;
                else
                    error('mod_v_obs:tempResDiff',['Each '...
                        'time-series element for the observed '...
                        'data has ' ...
                        num2str(numel(dataAll{cntrObs,iODate}(1,:))) ...
                        ' componenents while the modelled data '...
                        'has ' num2str(numel(dataAll{cntrObs,iMDate}(1,:)))...
                        '.  This has not been programmed for.']);
                end
            end

            %Find dates common to both modelled and observed data
            [~, dateUseObs, dateUseMod] = intersect(dataAll{cntrObs,iODate}, dataAll{cntrObs,iMDate},'rows');
            
%             if (sum(~isnan(dateUseObs)) < 0.7*sum(~isnan(dataAll{cntrObs,indObsData}))) || (numel(dateUseObs) < 0.7*numel(dataAll{cntrObs,indObsData}))
%                 warning('mod_v_obs:unusedObs',...
%                     [num2str(sum(~isnan(dateUseObs))) ' of the ' ...
%                     num2str(sum(~isnan(dataAll{cntrObs,indObsData}))) ...
%                     ' observations for ' char(nmDataCurrObs) ' are being '...
%                     'used.  Consider adapting the model '...
%                     'run time accordingly.']);
%             end
            
            dataAll{cntrObs,iMDate} = dataAll{cntrObs,iMDate}( dateUseMod,:);
            dataAll{cntrObs,iMData} = dataAll{cntrObs,iMData}( dateUseMod,:);
            dataAll{cntrObs,iODate} = dataAll{cntrObs,iODate}( dateUseObs,:);
            dataAll{cntrObs,iOData} = dataAll{cntrObs,iOData}( dateUseObs,:);
                       
            if isempty(dateUseObs) || isempty(dateUseMod)
                warning('mod_v_obs:noOverlapObs',...
                    ['There is no overlap between modelled output '...
                    'and observations for ' char(fldCurrObs) ...
                    '. Consider adapting the model '...
                    'run time accordingly.']);
                continue
            end

        elseif isfield(sObs.(ptsObs{ii}), [fldCurrObs{kk} '_dateStart']) && isfield(sObs.(ptsObs{ii}), [fldCurrObs{kk} '_dateEnd'])
            dataAll{cntrObs,iODate} = cell(2,1);
            dataAll{cntrObs,iODate}{1} = sObs.(ptsObs{ii}).([fldCurrObs{kk} '_dateStart']); 
            dataAll{cntrObs,iODate}{2} = sObs.(ptsObs{ii}).([fldCurrObs{kk} '_dateEnd']);
            tResObs = numel(dataAll{cntrObs,iODate}{1}(1,:));


            %Match observation and modelled dates differently
            %depending on resolutions:             
            if tResObs ~= tResMod 
                if tResObs == 3 && tResMod == 2
                    %Interpolate modelled data to daily resolution
                    %and extract for same dates present in
                    %observations

                    datesTempModInterp = date_vec_fill([dataAll{cntrObs,iMDate}(1,:),1],[dataAll{cntrObs,iMDate}(end,:),eomday(dataAll{cntrObs,iMDate}(end,1), dataAll{cntrObs,iMDate}(end,2))],'gregorian');

                    warning('off', 'all'); %Warning caused if all modelled data are NaN
                    dataAll{cntrObs,iMData} = interp_month2day(dataAll{cntrObs,iMDate}, dataAll{cntrObs,iMData}, datesTempModInterp, 'pchip', 1);
                    warning('on', 'all');
                    dataAll{cntrObs,iMDate} = datesTempModInterp;
                else
                    error('mod_v_obs:tempResDiff',['Each '...
                        'time-series element for the observed '...
                        'data has ' ...
                        num2str(numel(dataAll{cntrObs,iODate}(1,:))) ...
                        ' componenents while the modelled data '...
                        'has ' num2str(numel(dataAll{cntrObs,iMDate}(1,:)))...
                        '.  This has not been programmed '...
                        'for.  The observation data has '...
                        'start and end dates']);
                end
            end


            %Extract modelled data for time-series present in observations:
            if numel(size(dataAll{cntrObs,iOData})) == 2 && any(size(dataAll{cntrObs,iOData}) == 1) %Pt data
                dataTempMod2Obs = nan(numel(dataAll{cntrObs,iOData}),1);
                for ll = 1 : numel(dataAll{cntrObs,iOData})
                    indModStrt = find(ismember(dataAll{cntrObs,iMDate}, dataAll{cntrObs,iODate}{1}(ll,:), 'rows') == 1);
                    indModEnd = find(ismember(dataAll{cntrObs,iMDate}, dataAll{cntrObs,iODate}{2}(ll,:), 'rows') == 1);

                    if ~isempty(indModStrt) && ~isempty(indModEnd) && indModEnd >= indModStrt %If start and end dates of observation present in model, copy data
                        if regexpbl(evalType, 'sum')
                            dataTempMod2Obs(ll) = nansum(dataAll{cntrObs,iMData}(indModStrt:indModEnd));
                        elseif regexpbl(evalType, 'mean')
                            dataTempMod2Obs(ll) = nanmean(dataAll{cntrObs,iMData}(indModStrt:indModEnd));
                        elseif regexpbl(evalType, 'max')
                            dataTempMod2Obs(ll) = nanmax(dataAll{cntrObs,iMData}(indModStrt:indModEnd));
                        else
                            error('mod_v_obs:unknownEvalType', [evalType ...
                                ' is an unknown evaluation type and a '...
                                'case has not been programmed for it.']);
                        end
                    else
                        dataAll{cntrObs,iOData}(ll) = nan;
                    end
                end
            elseif numel(size(dataAll{cntrObs,iOData})) == 3 || ~any(size(dataAll{cntrObs,iOData}) == 1) %gridded data
                if numel(size(dataAll{cntrObs,iOData})) == 3 %Observations have 3 dimensions
                    nTsObs = numel(dataAll{cntrObs,iOData}(:,1,1));
                    dataTempMod2Obs = nan(size(dataAll{cntrObs,iOData}),'single');             
                else
                    nTsObs = 1;
                    dataTempMod2Obs = nan([1,size(dataAll{cntrObs,iOData})],'single'); 
                end

                for ll = 1 : nTsObs
                    if isnumeric(dataAll{cntrObs,iMDate}) || (iscell(dataAll{cntrObs,iMDate}) && numel(dataAll{cntrObs,iMDate}) == 1) %Date field at model time step
                        indModStrt = find(ismember(dataAll{cntrObs,iMDate}, dataAll{cntrObs,iODate}{1}(ll,:), 'rows') == 1);
                        indModEnd = find(ismember(dataAll{cntrObs,iMDate}, dataAll{cntrObs,iODate}{2}(ll,:), 'rows') == 1);
                        
                        if ~isempty(indModStrt) && ~isempty(indModEnd) && indModEnd >= indModStrt %If start and end dates of observation present in model, copy data
                            if regexpbl(evalType, 'sum')
                                dataTempMod2Obs(ll,:,:) = squeeze(nansum(dataAll{cntrObs,iMData}(indModStrt:indModEnd,:,:), 1));
                            elseif regexpbl(evalType, 'mean')
                                dataTempMod2Obs(ll,:,:) = squeeze(nanmean(dataAll{cntrObs,iMData}(indModStrt:indModEnd,:,:), 1));
                            elseif regexpbl(evalType, 'max')
                                dataTempMod2Obs(ll,:,:) = squeeze(nanmax(dataAll{cntrObs,iMData}(indModStrt:indModEnd,:,:), 1));
                            else
                                error('mod_v_obs:unknownEvalType', [evalType ...
                                    ' is an unknown evaluation type and a '...
                                    'case has not been programmed for it.']);
                            end
                        else
                            dataAll{cntrObs,iOData}(ll,:,:) = nan;
                        end
                    elseif iscell(dataAll{cntrObs,iMDate}) && numel(dataAll{cntrObs,iMDate}(:)) == 2 %Start and end dates for model field
                        %Geodetic observations are gridded and span two points
                        %in time (typically many years). Observation time 
                        %interval may not overlap perfectly with modelled 
                        %time-series.
                        nDatesMod = numel(dataAll{cntrObs,iMDate}{1}(:,1));
                        
                        %Find days seperating mod and obs
                        daysStrtTemp = nan(nDatesMod,1);
                        daysEndTemp = daysStrtTemp;
                        for zz = 1 : nDatesMod
                            daysStrtTemp(zz) = days_since(dataAll{cntrObs,iODate}{1}(ll,:), dataAll{cntrObs,iMDate}{1}(zz,:), 'gregorian');
                            daysEndTemp(zz)  = days_since(dataAll{cntrObs,iMDate}{2}(zz,:), dataAll{cntrObs,iODate}{2}(ll,:), 'gregorian');
                        end
                        
                        %Find indices of model that best include
                        %observations (going over if necessary)
                        %For start:
                        if any(daysStrtTemp <= 0)
                            indModStrt = find(daysStrtTemp <= 0, 1, 'last');
                        else
                            indModStrt = 1;
                        end
                        %For end:
                        if any(daysEndTemp <= 0)
                            indModEnd = find(daysEndTemp <= 0, 1, 'first');
                        else
                            indModEnd = numel(daysEndTemp);
                        end
                        
                        %Interpolate model to observation dates:
                        nDaysMod = days_since(dataAll{cntrObs,iMDate}{1}(indModStrt,:), dataAll{cntrObs,iMDate}{2}(indModEnd,:), 'gregorian');
                        nDaysObs = days_since(dataAll{cntrObs,iODate}{1}(ll,:), dataAll{cntrObs,iODate}{2}(ll,:), 'gregorian');
                        dataTempMod2Obs(ll,:,:) = (nDaysObs/nDaysMod)*squeeze(sum(dataAll{cntrObs,iMData}(indModStrt:indModEnd,:,:), 1));
                        %For testing:
                        %figure; imagesc(squeeze(dataTempMod2Obs(ll,:,:))); colorbar;
                    else
                        error('modVObs:unknownDateFormat',['The model date is of class ' class(dataAll{cntrObs,iMDate}) ' and has ' num2str(numel(dataAll{cntrObs,iMDate})) ' elements. This has not been programmed for.']);
                    end
                end %End of loop over observations
            else
                error('mod_v_obs:errDim', ['The current variable has ' ...
                    num2str(numel(size(numel(dataAll{cntrObs,iOData})))) ...
                    ' dimensions, which has not been programmed for.']);
            end

            %Copy aggregated model data to data array:
            dataAll{cntrObs,iMData} = dataTempMod2Obs;
            
            %Remove all empty elements for point observation data:
            if numel(size(dataAll{cntrObs,iOData})) == 2
                indRemCurr = find(isnan(dataAll{cntrObs,iOData}));
                if ~isempty(indRemCurr)
                    dataAll{cntrObs,iOData}(indRemCurr) = []; %Observation data field
                    dataAll{cntrObs,iMData}(indRemCurr) = []; %Modeled data field
                    dataAll{cntrObs,iODate}{1}(indRemCurr,:) = []; %Observation start date
                    dataAll{cntrObs,iODate}{2}(indRemCurr,:) = []; %Observation end date
                end
            end
            
            %Set model output dates to be same as observation (because
            %model output has been aggregated to observation time elements)
            dataAll{cntrObs,iMDate} = dataAll{cntrObs,iODate}; %Model start date
        else
            error('mod_v_obs:noDate',['No time field appears to be present for ' sObs.(ptsObs{ii}) ' observation data.'])
        end


        %Save time signature as reference date and "days_since" instead of
        %date:
        dateRef = nan(tResMod, 1);
        if iscell(dataAll{cntrObs,iMDate}) && iscell(dataAll{cntrObs,iODate})
            if ~isempty(dataAll{cntrObs,iMDate}{1}) && numel(dataAll{cntrObs,iMDate}{1}(1,:)) > 1 && ~isempty(dataAll{cntrObs,iODate}{1}) && numel(dataAll{cntrObs,iODate}{1}(1,:)) > 1
                dateRef = dataAll{cntrObs,iMDate}{1}(1,:);
                for ll = 1 : numel(dataAll{cntrObs,iMDate})
                    dataAll{cntrObs,iMDate}{ll} = days_since(dateRef, dataAll{cntrObs,iMDate}{ll}, 'gregorian');
                    dataAll{cntrObs,iODate}{ll} = days_since(dateRef, dataAll{cntrObs,iODate}{ll}, 'gregorian');
                end
            end
        elseif iscell(dataAll{cntrObs,iMDate})
            if ~isempty(dataAll{cntrObs,iMDate}{1}) && numel(dataAll{cntrObs,iMDate}{1}(1,:)) > 1
                dateRef = dataAll{cntrObs,iMDate}{1}(1,:);
                for ll = 1 : numel(dataAll{cntrObs,iMDate})
                    dataAll{cntrObs,iMDate}{ll} = days_since(dateRef, dataAll{cntrObs,iMDate}{ll}, 'gregorian');
                end
            end
            dataAll{cntrObs,iODate} = days_since(dateRef, dataAll{cntrObs,iODate}, 'gregorian');
        elseif iscell(dataAll{cntrObs,iODate})
            if ~isempty(dataAll{cntrObs,iODate}{1}) && numel(dataAll{cntrObs,iODate}{1}(1,:)) > 1
                dateRef = dataAll{cntrObs,iODate}{1}(1,:);
                for ll = 1 : numel(dataAll{cntrObs,iODate})
                    dataAll{cntrObs,iODate}{ll} = days_since(dateRef, dataAll{cntrObs,iODate}{ll}, 'gregorian');
                end
            end
            dataAll{cntrObs,iMDate} = days_since(dateRef, dataAll{cntrObs,iMDate}, 'gregorian');
        else
            if ~isempty(dataAll{cntrObs,iMDate}) && numel(dataAll{cntrObs,iMDate}(1,:)) > 1
                dateRef = dataAll{cntrObs,iMDate}(1,:);
                dataAll{cntrObs,iMDate} = days_since(dateRef, dataAll{cntrObs,iMDate}, 'gregorian');
                dataAll{cntrObs,iODate} = days_since(dateRef, dataAll{cntrObs,iODate}, 'gregorian');
            end
        end
        
        if all(isnan(dateRef))
           warning('mod_v_obs:noRefDate',...
                    ['The reference date for ' char(fldCurrObs) ...
                    ' could not be found. This variable is therefore '...
                    'being skipped.']);
                continue 
        end

        
        %Write metadata for current observation-model:
            % {Measurement Type; reference date dateRef; [lon, lat]; evalulation metric ; evalulation type (sum, max, mean, ...)};
        %This could be defined within the ii loop, but by having it in the
        %kk loop it will be empty if no datafield found.
        dataAll{cntrObs,iMeta}(1:3) = {fldCurrObs{kk}; dateRef; [sObs.(ptsObs{ii}).lon, sObs.(ptsObs{ii}).lat]};
        dataAll{cntrObs,iMeta}{5} = intrpType;
        %Diagnostics:
        %max(dataAll{cntrObs,iMData}(:))
        %min(dataAll{cntrObs,iMData}(:))
        %max(dataAll{cntrObs,iOData}(:))
        %min(dataAll{cntrObs,iOData}(:))

        %If mass balance convert units from total change to change per year
        if regexpbl(fldCurrObs{kk}, varMb) || regexpbl(fldCurrObs{kk}, varGeodetic) || regexpbl(fldCurrObs{kk}, varStake) 
            dysInYr = 365.25;
            nDimCurr = ndims(dataAll{cntrObs,iMData});
            if nDimCurr == 3
                nTs = numel(dataAll{cntrObs,iMData}(:,1,1)); 
            else
                nTs = numel(dataAll{cntrObs,iMData}(:,1));
            end

            if iscell(dataAll{cntrObs,iMDate})
                for zz = 1 : nTs
                    daysMod = dataAll{cntrObs,iMDate}{2}(zz) - dataAll{cntrObs,iMDate}{1}(zz);
                    daysObs = dataAll{cntrObs,iODate}{2}(zz) - dataAll{cntrObs,iODate}{1}(zz);
                    
                    if nDimCurr == 3
                        dataAll{cntrObs,iMData}(zz,:,:) = (dysInYr/daysMod)*dataAll{cntrObs,iMData}(zz,:,:);
                        dataAll{cntrObs,iOData}(zz,:,:) = (dysInYr/daysObs)*dataAll{cntrObs,iOData}(zz,:,:);
                        %Diagnostics:
%                       max2d(squeeze(dataAll{cntrObs,iMData}(zz,:,:)))
%                       min2d(squeeze(dataAll{cntrObs,iMData}(zz,:,:)))
%                       max2d(squeeze(dataAll{cntrObs,iOData}(zz,:,:)))
%                       min2d(squeeze(dataAll{cntrObs,iOData}(zz,:,:)))
%                       figure; imagesc(squeeze(dataAll{cntrObs,iOData}(zz,:,:))); colorbar;
%                       figure; imagesc(squeeze(dataAll{cntrObs,iMData}(zz,:,:))); colorbar;
                    else
                        dataAll{cntrObs,iMData}(zz,:) = (dysInYr/daysMod)*dataAll{cntrObs,iMData}(zz,:);
                        dataAll{cntrObs,iOData}(zz,:) = (dysInYr/daysObs)*dataAll{cntrObs,iOData}(zz,:);
                    end
                end
            else
                error('modVObs:dateNotCellMb','The glacier mass balance date is not a cell. This indicates that the mass balance entry uses the model time step. This is not programmed for.')
            end
        end
    end %End of loop over fields in observation data  
end %End of loop over points in observation data


%Remove empty series from combined array:
for kk = numel(dataAll(:,1)) : -1 : 1
    if isempty(dataAll{kk,iMeta}) 
        if numel(size(dataAll{kk,iMData})) == 3 && (all(isnan(dataAll{kk,iMData}(:))) || all(isnan(dataAll{kk,iOData}(:))))
            dataAll(kk,:) = [];
        elseif all2d(isnan(dataAll{kk,iMData})) || all2d(isnan(dataAll{kk,iOData}))
            dataAll(kk,:) = [];
        end
    elseif isempty(dataAll{kk,iMData}) && isempty(dataAll{kk,iOData})
        dataAll(kk,:) = [];
    end
end


%Parse evaluation metrics to use:
if ischar(methRank)
   methRank = {methRank};
elseif ~iscell(methRank)
    error('modVObs:unknownRankingClass', ['The fitness metric is of class ' class(methRank) ', which has not been programmed for.'])
end
nMetric = numel(methRank(:));
for ii = 1 : numel(dataAll(:,1))

    obsCurr = dataAll{ii,iMeta}{1};
    evalCurr = cell(nMetric, 1);
    [evalCurr{:}] = deal(blanks(0));
    for jj = 1 : nMetric
        %'Parajka' can only be used for snow covered area
        if regexpbl(obsCurr, {'casi', 'icx', 'snx', 'sca'})
            if regexpbl(methRank{jj}, 'Parajka')
                evalCurr{jj} = 'Parajka';
            else
                evalCurr{jj} = methRank{jj};
            end
        elseif regexpbl(obsCurr, varMb) || regexpbl(obsCurr, varGeodetic)
            if regexpbl(methRank{jj}, 'mbe')
                evalCurr{jj} = 'mbe';
            elseif regexpbl(methRank{jj}, 'mae')
                evalCurr{jj} = 'mae';
            elseif regexpbl(methRank{jj}, 'mape')
                evalCurr{jj} = 'mae';
            else
                evalCurr{jj} = methRank{jj};
            end
        else
            evalCurr{jj} = methRank{jj};
            
            %Remove 'Parajka' metric reference
            indMeth = regexpi(evalCurr{jj},'Parajka');
            if ~isempty(indMeth)
                evalCurr{jj}(indMeth:indMeth+6) = [];
            end
            
            %Remove underscores from start or end of method rank string:
            if regexpbl(evalCurr{jj}(1),'_')
                evalCurr{jj} = evalCurr{jj}(2:end);
            end
            if regexpbl(evalCurr{jj}(end),'_')
                evalCurr{jj} = evalCurr{jj}(1:end-1);
            end
            
            %Remove MBE:
            indMeth = regexpi(evalCurr{jj},'mbe');
            if ~isempty(indMeth) 
                evalCurr{jj}(indMeth:indMeth+2) = [];
            end
            
            %Remove underscores from start or end of method rank string:
            if regexpbl(evalCurr{jj}(1),'_')
                evalCurr{jj} = evalCurr{jj}(2:end);
            end
            if regexpbl(evalCurr{jj}(end),'_')
                evalCurr{jj} = evalCurr{jj}(1:end-1);
            end
        end
        
        %Remove underscores from start or end of method rank string:
        if regexpbl(evalCurr{jj}(1),'_')
            evalCurr{jj} = evalCurr{jj}(2:end);
        end
        if regexpbl(evalCurr{jj}(end),'_')
            evalCurr{jj} = evalCurr{jj}(1:end-1);
        end
        if regexpbl(evalCurr{jj}, '_')
            warning('modVObs:evalMethodUnderscoe',['The evaluation metric for ' ...
                obsCurr ' is ' evalCurr{jj} '. It is not expected for there ' ...
                'to be an underscore in the method name.'])
        end
    end %End of loop over metrics
    
    dataAll{ii,iMeta}{4} = evalCurr;
end


%%CALCULATE FITNESS SCORES
nMetric = numel(methRank);
scoreTemp = cell(nMetric, 1);
nmScore   = cell(nMetric, 1);
if regexpbl(typeCombine,'type') %Evaluate individually for each seperate observation and then combined based on unique types of observations (i.e. combine observation performance for same type)
    [scoreTemp{:}] = deal( nan(numel(obsTypes), 1));
    [  nmScore{:}] = deal(cell(numel(obsTypes), 1));
    for kk = 1 : nMetric
        for ii = 1 : numel(obsTypes)
            indCurrType = nan(numel(dataAll(:,1)),1);
            for indCurr = 1 : numel(dataAll(:,1))
                indCurrType(indCurr) = strcmpi(obsTypes{ii}, dataAll{indCurr,iMeta}{1});
            end
            indCurrType = find(indCurrType == 1);

            fitTemp = nan(size(indCurrType));
            for indCurr = 1 : numel(indCurrType)
                if ~isempty(dataAll{indCurrType(indCurr),iMData}) && ~isempty(dataAll{indCurrType(indCurr),iOData}) 
                    fitTemp(indCurr) = ...
                        fitness(dataAll{indCurrType(indCurr),iOData}, dataAll{indCurrType(indCurr),iMData}, dataAll{indCurrType(indCurr),iMeta}{4}{kk}, rmMod);
                end
            end

            %Combine scored for current type:
            if ~isempty(fitTemp)
                switch statCombine
                    case 'linear'
                        scoreTemp{kk}(ii) = nanmean(fitTemp);
                    case 'square'
                        scoreTemp{kk}(ii) = sqrt(nansum(fitTemp.^2));
                end

                nmScore{kk}{ii} = char(obsTypes{ii});
            end
        end
    end
elseif regexpbl(typeCombine,'lump') %Combine all data of same observation prior to evaluating
    [scoreTemp{:}] = deal( nan(numel(obsTypes), 1));
    [  nmScore{:}] = deal(cell(numel(obsTypes), 1));
    for kk = 1 : nMetric
        for ii = 1 : numel(obsTypes)
            indCurrType = nan(numel(dataAll(:,1)),1);
            for jj = 1 : numel(dataAll(:,1))
                indCurrType(jj) = strcmpi(obsTypes{ii}, dataAll{jj,iMeta}{1});
            end
            indCurrType = find(indCurrType == 1);

            dataFitTempMod = [];
            dataFitTempObs = [];
            for jj = 1 : numel(indCurrType)
                dataFitTempMod = [dataFitTempMod; dataAll{indCurrType(jj),iMData}];
                dataFitTempObs = [dataFitTempObs; dataAll{indCurrType(jj),iOData}];
            end

            if ~isempty(dataFitTempObs) && ~isempty(dataFitTempMod) 
                scoreTemp{kk}(ii) = fitness(dataFitTempObs, dataFitTempMod, dataAll{indCurrType(jj),iMeta}{4}{kk}, rmMod);
                nmScore{kk}{ii} = char(obsTypes{ii});
            else
                scoreTemp{kk}(ii) = nan;
            end
        end
    end
else
    [scoreTemp{:}] = deal( nan(numel(dataAll(:,1)),1));
    [  nmScore{:}] = deal(cell(numel(dataAll(:,1)), 1));
    for kk = 1 : nMetric
        for ii = 1 : numel(dataAll(:,1))
            if ~isempty(dataAll{ii,iOData}) && ~isempty(dataAll{ii,iMData}) 
                scoreTemp{kk}(ii) = fitness(dataAll{ii,iOData}, dataAll{ii,iMData}, dataAll{ii,iMeta}{4}{kk}, rmMod);
                nmScore{kk}{ii} = [char(dataAll{ii,iMeta}{1}), ' (' num2str(round2(dataAll{ii,iMeta}{3}(1),3)) ', ' num2str(round2(dataAll{ii,iMeta}{3}(2),3)) ')'];
            end
        end
    end
end

%Remove empty fields / scores
for kk = 1 : nMetric
    for ii = numel(nmScore{kk}) : -1 : 1
       if isempty(nmScore{kk}{ii})
           nmScore{kk}(ii) = [];
           scoreTemp{kk} = scoreTemp{kk}((1:numel(scoreTemp)) ~= ii); 
       end
    end
end
    
if flagOneStat == 1
    %%COMBINE FITNESS SCORES:
    scoreOut = cell(nMetric, 1);
    for kk = 1 : nMetric
        switch statCombine
            case 'linear'
                scoreOut{kk} = nanmean(scoreTemp{kk});
            case 'square'
                scoreOut{kk} = sqrt(nansum(scoreTemp{kk}.^2));
        end 

        nmTemp = blanks(0);
        for ii = numel(nmScore{kk})
            nmTemp = [nmTemp '-' nmScore{kk}{ii}];
        end

        nmScore{kk} = {'Combined' nmTemp};
   end
else
    scoreOut = scoreTemp;
end


%%PLOT OBSERVATION AND MODEL DATA:
if flagPlot == 1 && numel(dataAll(:,1)) ~= 0
    %%SET PROPERTIES:
    %Set plot size:
    szFrame = [8 5];
    %Set font size:
    ftSz = 14;
        ftSzAx = ftSz - 2;
        ftSzLgd = ftSz - 4;
    %Set line width:
    lnWd = 2;
        lnWdA = lnWd - 0.5;
    %Set font:
    strFont = 'Arial';

    %Use these colors instead?
    %From color Brewer):
    clrBrewer = [228,26,28; ...
        55,126,184; ...
        77,175,74; ...
        152,78,163]/255;
    custGray = [0.5,0.5,0.5];

    for ii = 1 : numel(obsTypes)
        %Guess units:
        switch obsTypes{ii}
            case 'stake'
                unitCurr = 'm W.E.';
                varCurr = 'Change in Snow and Ice';
            case 'snowradar'
                unitCurr = '(W.E. m)';
                varCurr = 'Snow';
            case 'flow'
                unitCurr = 'm^3/s';
                varCurr = 'Discharge';
            case 'flowrate'
                unitCurr = 'm^3/s';
                varCurr = 'Discharge';
            case 'sca'
                unitCurr = '% Area';
                varCurr = 'Snow Covered Area';
            case 'casi'
                unitCurr = '% Area';
                varCurr = 'Snow and Ice Covered Area';
            case varGeodetic
                unitCurr = 'm/yr W.E.';
                varCurr = 'Change in Snow and Ice';
            case 'icmb'
                unitCurr = 'm/yr W.E.';
                varCurr = 'Change in Ice';
            otherwise
                unitCurr = '?';
                varCurr = obsTypes{ii};
        end

        if ~isempty(typeCombine)
            indCurrType = nan(numel(dataAll(:,1)),1);
            for indCurr = 1 : numel(dataAll(:,1))
                indCurrType(indCurr) = strcmpi(obsTypes{ii}, dataAll{indCurr,iMeta}{1});
            end
            if all(indCurrType == 0)
               continue 
            end
            indCurrType = {find(indCurrType == 1)};
            nPlot = 1;
        else
            nPlot = numel(dataAll(:,1));
            indCurrType = cell(nPlot,1);
            for ll = 1 : nPlot
                indCurrType{ll} = ll;
            end
        end
        

        %Loop over each plot:
        for ll = 1 : nPlot
            szCurr = size(dataAll{indCurrType{ll}(1),iOData});
            if numel(dataAll{indCurrType{ll}(1),iMDate}) == 2
                nDtCurr = numel(dataAll{indCurrType{ll}(1),iMDate}{1}(:,1));
                dateTyp = 2;
            else
                nDtCurr = numel(dataAll{indCurrType{ll}(1),iMDate}(:,1));
                dateTyp = 1;
            end

            %Make gridded plots if data are gridded
            if ((szCurr(1) == nDtCurr && numel(szCurr) == 3) || (szCurr(1) ~= nDtCurr && numel(szCurr) == 2)) && flagGrid
                if isdir(outputPath)
                    dirWrite = outputPath;
                    fileWrite = '';
                else
                    [dirWrite, fileWrite, ~] = fileparts(outputPath);
                end
                
                %Use imagesc to plot data:
                custClrMap = ... 
                    [0,0,1; ... %blue
                    0.2,0.2,1; ...
                    0.4,0.4,1; ...
                    0.6,0.6,1; ...
                    0.8,0.8,1; ...
                    1, 1, 1; ... %white
                    1, 0.8, 0.8; ...
                    1, 0.6, 0.6; ...
                    1, 0.4, 0.4; ...
                    1, 0.2, 0.2; ...
                    1, 0, 0]; %red
%                     0.7, 0.7, 0.7]; %Gray 
                
                %Initialize arrays:
                gridObsCurr = nan([nDtCurr, szCurr(end-1:end)], 'single');
                gridModCurr = nan([nDtCurr, szCurr(end-1:end)], 'single');
                dataErrCurr = nan([nDtCurr, szCurr(end-1:end)], 'single');
                dataMapeCurr = nan([nDtCurr, szCurr(end-1:end)], 'single');
                
                %loop over all iterations of the observations
                for kk = 1 : nDtCurr
                    %Format data for plotting (Mod - Obs):
                    %Set values to nan where change in observation is exactly 0: 
                    if numel(szCurr) == 3
                        gridObsCurr(kk,:,:) = squeeze(dataAll{indCurrType{ll}(1),iOData}(kk,:,:));
                        gridModCurr(kk,:,:) = squeeze(dataAll{indCurrType{ll}(1),iMData}(kk,:,:));
                        dataErrCurr(kk,:,:) = gridModCurr(kk,:,:) - gridObsCurr(kk,:,:);
                        
                        dataMapeTemp = 100*squeeze((dataAll{indCurrType{ll}(1),iMData}(kk,:,:) - gridObsCurr(kk,:,:))./gridObsCurr(kk,:,:));
                        dataMapeTemp(isnan(squeeze(gridObsCurr(kk,:,:)))) = nan;
                        dataMapeTemp(isnan(squeeze(dataAll{indCurrType{ll}(1),iMData}(kk,:,:)))) = nan;
                        
                        dataMapeCurr(kk,:,:) = dataMapeTemp;
                        
%                         sz2d = size(gridObsCurr);
                    else
                        gridObsCurr(kk,:,:) = dataAll{indCurrType{ll}(1),iOData};
                        gridModCurr(kk,:,:) = dataAll{indCurrType{ll}(1),iMData};
                        dataErrCurr(kk,:,:) = gridModCurr - gridObsCurr;
                        dataMapeCurr(kk,:,:) = 100*(gridModCurr - gridObsCurr)./gridObsCurr;
                       
%                         sz2d = size(dataAll{indCurrType{ll}(1),indObsData});
                    end
%                     %Set to nan:
%                     if strcmpi(obsTypes{ii}, 'geodetic')
%                         indNan2d = find(gridObsCurr == 0);
%                         [nanRow, nanCol] = ind2sub(sz2d, indNan2d);
%                         sz3d = size(dataErrCurr);
%                         indNan3d = kk + (nanRow-1)*sz3d(1) + (nanCol-1)*sz3d(2)*sz3d(1);
%                         dataErrCurr(indNan3d) = nan;
%                         datMapeCurr(indNan3d) = nan;
%                     end
                    
                    if nDtCurr <= 10 %Only make output figures if there are 10 or fewer observations
                        %Plot observed grid:
                        hFig = figure('Units','in','Position',[2 2 szFrame],'paperunits','in','paperposition',[2 2 szFrame], 'Color',[1 1 1]);

                        %Remove any "nan border" caused by different
                        %geographic domains:
                        [gridObsPlot, latPlot, lonPlot] = rm_nan_border(squeeze(gridObsCurr(kk,:,:)), lat, lon);
                        [gridModPlot, latPlot, lonPlot] = rm_nan_border(squeeze(gridModCurr(kk,:,:)), lat, lon);
                        
                        cLim = max([max2d(abs(gridModPlot)), max2d(abs(gridObsPlot))]);
                        
%                         gridObsCurr(isnan(gridObsCurr)) = cLim + 0.1*cLim;
                        if all(~isnan(lon)) && all(~isnan(lat))
                            imagesc(lonPlot, latPlot, gridObsPlot);
                            xlim([min(lonPlot), max(lonPlot)]);
                            ylim([min(latPlot), max(latPlot)]);
                        else   
                            imagesc(gridObsPlot);
                        end
                        whitebg([0.6,0.6,0.6]);
                        set(hFig, 'color', 'white');
%                         set(gca,'Color',[0.8 0.8 0.8]);
                        shading flat; 
                        colormap(custClrMap);
                        caxis([-cLim cLim]);
                        hCBar = colorbar;  
                        hTitle = title(['Observed ' varCurr ' (' unitCurr ')']);

                        %Set plot properties:
                        set(gca, ...
                            'FontName'   , strFont);
                        set([hTitle, hCBar], ...
                            'FontName'   , strFont, ...
                            'fontSize', ftSzAx);
                        set(gca, ...
                            'Box'         , 'on', ...
                            'TickDir'     , 'in'     , ...
                            'TickLength'  , [.02 .02] , ...
                            'LineWidth'   , lnWdA , ...
                            'fontSize', ftSzAx);   

                        if ~isempty(fileWrite)
                            pathWrite = fullfile(dirWrite, [fileWrite '_' num2str(ii)]);
                        else
                            pathWrite = fullfile(dirWrite, [obsTypes{ii} '_obs_grid']);
                        end

                        if nDtCurr > 1
                            pathWrite = [char(pathWrite), '_' num2str(kk)];
                        end

                        savefig(hFig, [pathWrite '.fig']);
                        print(hFig, [pathWrite '.eps'],'-depsc2');
                        print(hFig, [pathWrite '.png'],'-dpng','-r600');
                        
                        
                        %Plot modelled grid:
                        hFig = figure('Units','in','Position',[2 2 szFrame],'paperunits','in','paperposition',[2 2 szFrame], 'Color',[1 1 1]);

%                         gridModCurr(isnan(gridModCurr)) = cLim + 0.1*cLim;
                        if all(~isnan(lon)) && all(~isnan(lat))
                            imagesc(lonPlot, latPlot, gridModPlot);
                            xlim([min(lonPlot), max(lonPlot)]);
                            ylim([min(latPlot), max(latPlot)]);
                        else   
                            imagesc(gridModPlot);
                        end
                        whitebg([0.6,0.6,0.6]);
                        set(hFig, 'color', 'white');
%                         set(gca,'Color',[0.8 0.8 0.8]);
                        shading flat; 
                        colormap(custClrMap);
                        caxis([-cLim cLim]);
                        hCBar = colorbar;  
                        hTitle = title(['Modelled ' varCurr ' (' unitCurr ')']);

                        %Set plot properties:
                        set(gca, ...
                            'FontName'   , strFont);
                        set([hTitle, hCBar], ...
                            'FontName'   , strFont, ...
                            'fontSize', ftSzAx);
                        set(gca, ...
                            'Box'         , 'on', ...
                            'TickDir'     , 'in'     , ...
                            'TickLength'  , [.02 .02] , ...
                            'LineWidth'   , lnWdA , ...
                            'fontSize', ftSzAx);   

                        if ~isempty(fileWrite)
                            pathWrite = fullfile(dirWrite, [fileWrite '_' num2str(ii)]);
                        else
                            pathWrite = fullfile(dirWrite, [obsTypes{ii} '_mod_grid']);
                        end

                        if nDtCurr > 1
                            pathWrite = [char(pathWrite), '_' num2str(kk)];
                        end

                        savefig(hFig, [pathWrite '.fig']);
                        print(hFig, [pathWrite '.eps'],'-depsc2');
                        print(hFig, [pathWrite '.png'],'-dpng','-r600');
                        
                        
                        %PLOT LEVEL ERROR
                        hFig = figure('Units','in','Position',[2 2 szFrame],'paperunits','in','paperposition',[2 2 szFrame], 'Color',[1 1 1]);

                        %Remove any "nan border" caused by different
                        %geographic domains:
                        [dataPlot, latPlot, lonPlot] = rm_nan_border(squeeze(dataErrCurr(kk,:,:)), lat, lon);
                        
                        cLim = max2d(abs(dataPlot));
%                         dataPlot(isnan(dataPlot)) = cLim + 0.1*cLim;
                        if all(~isnan(lon)) && all(~isnan(lat))
                            imagesc(lonPlot, latPlot, dataPlot);
                            xlim([min(lonPlot), max(lonPlot)]);
                            ylim([min(latPlot), max(latPlot)]);
                        else   
                            imagesc(dataPlot);
                        end
                        whitebg([0.6,0.6,0.6]);
                        set(hFig, 'color', 'white');
%                         set(gca,'Color',[0.8 0.8 0.8]);
                        shading flat; 
                        colormap(custClrMap);
                        caxis([-cLim cLim]);
                        hCBar = colorbar;  
                        hTitle = title(['Modelled Minus Observed ' varCurr ' (' unitCurr ')']);

                        %Set plot properties:
                        set(gca, ...
                            'FontName'   , strFont);
                        set([hTitle, hCBar], ...
                            'FontName'   , strFont, ...
                            'fontSize', ftSzAx);
                        set(gca, ...
                            'Box'         , 'on', ...
                            'TickDir'     , 'in'     , ...
                            'TickLength'  , [.02 .02] , ...
                            'LineWidth'   , lnWdA , ...
                            'fontSize', ftSzAx);   

                        if ~isempty(fileWrite)
                            pathWrite = fullfile(dirWrite, [fileWrite '_' num2str(ii)]);
                        else
                            pathWrite = fullfile(dirWrite, [obsTypes{ii} '_mod_v_obs_lvl_err']);
                        end

                        if nDtCurr > 1
                            pathWrite = [char(pathWrite), '_' num2str(kk)];
                        end
                        
                        savefig(hFig, [pathWrite '.fig']);
                        print(hFig, [pathWrite '.eps'],'-depsc2');
                        print(hFig, [pathWrite '.png'],'-dpng','-r600');
                        

                        %PLOT PERCENT ERROR:
                        hFig = figure('Units','in','Position',[2 2 szFrame],'paperunits','in','paperposition',[2 2 szFrame], 'Color',[1 1 1]);

                        %Remove any "nan border" caused by different
                        %geographic domains:
                        [dataPlot, latPlot, lonPlot] = rm_nan_border(squeeze(dataMapeCurr(kk,:,:)), lat, lon);
                        dataPlot(isinf(dataPlot)) = nan;
                        
                        
                        cLim = max2d(abs(dataPlot));
                        cLim(cLim > 200) = 100;
                        
%                         dataPlot(isnan(dataPlot)) = cLim + 0.1*cLim;
                        if all(~isnan(lon)) && all(~isnan(lat))
                            imagesc(lonPlot, latPlot, dataPlot);
                            xlim([min(lonPlot), max(lonPlot)]);
                            ylim([min(latPlot), max(latPlot)]);
                        else   
                            imagesc(dataPlot);
                        end
                        whitebg([0.6,0.6,0.6]);
                        set(hFig, 'color', 'white');
%                         set(gca,'Color',[0.8 0.8 0.8]);
                        shading flat; 
                        colormap(custClrMap);
                        caxis(gca, [-cLim cLim]);
                        hCBar = colorbar(gca);  
                        hTitle = title(['Percent Error ' varCurr ' (%; thresh = 100%)']);

                        %Set plot properties:
                        set(gca, ...
                            'FontName'   , strFont);
                        set([hTitle, hCBar], ...
                            'FontName'   , strFont, ...
                            'fontSize', ftSzAx);
                        set(gca, ...
                            'Box'         , 'on', ...
                            'TickDir'     , 'in'     , ...
                            'TickLength'  , [.02 .02] , ...
                            'LineWidth'   , lnWdA , ...
                            'fontSize', ftSzAx);   

                        if ~isempty(fileWrite)
                            pathWrite = fullfile(dirWrite, [fileWrite '_' num2str(ii)]);
                        else
                            pathWrite = fullfile(dirWrite, [obsTypes{ii} '_mod_v_obs_per_err']);
                        end

                        if nDtCurr > 1
                            pathWrite = [char(pathWrite), '_' num2str(kk)];
                        end

                        savefig(hFig, [pathWrite '.fig']);
                        print(hFig, [pathWrite '.eps'],'-depsc2');
                        print(hFig, [pathWrite '.png'],'-dpng','-r600');
                        
                    end
                end %End of date loop
                

                %%Write evaluation grids to file:
                dateRef = dataAll{indCurrType{ll}(1),iMeta}{2};
                %Get dates and Estimate time bounds:
                if  dateTyp == 2
                    daysBndsOut = [dataAll{indCurrType{ll}(1),iMDate}{1}(:), dataAll{indCurrType{ll}(1),iMDate}{2}(:)];
                    
                    daysUse = nanmean(daysBndsOut, 2);
                    dateOut = days_2_date_v2(daysUse, dateRef, 'gregorian');
                    dateWrtOut = [{days_2_date_v2(daysBndsOut(:,1), dateRef, 'gregorian')}, {days_2_date_v2(daysBndsOut(:,2), dateRef, 'gregorian')}];
                elseif dateTyp == 1
                    daysOut = dataAll{indCurrType{ll}(1),iMDate};
                    
                    if nDtCurr > 2
                        dayStepTemp = abs(diff(daysOut(:,1)));
                        dayStep = mode(dayStepTemp);
                        if dayStep ~= dayStepTemp(1)
                           warning('mod_v_obs:dayStepWrong',['The  time step for ' ...
                               obsTypes{ii} ' was estimated as ' num2str(dayStep) ...
                               ' but this appears to be wrong.']); 
                        end
                        daysBndsOut = [daysOut - 0.5*dayStep; daysOut(end,:) + 0.5*dayStep];
                    else
                        daysBndsOut = [dataAll{indCurrType{ll}(1),iMDate}{1}(1,:); dataAll{indCurrType{ll}(1),iMDate}{2}(1,:)];
                    end
                    
                    dateOut = days_2_date(daysOut, dateRef, 'gregorian');
                    dateWrtOut = {dateOut};
                else
                    error('modVObs:unknownDateType',['The date type with ' num2str(dateTyp) ' has not been programmed for.'])
                end
                
                %Set parameters for writing files:
                nDec = 2;
                hdrOut = ESRI_hdr(lon, lat, 'corner');
                
                if regexpbl(wrtGridTyp, {'nc', 'netcdf'})
                    extWrt = 'nc';
                    
                    dateBndsOut = days_2_date(daysBndsOut, dateRef, 'gregorian');
                elseif regexpbl(wrtGridTyp, 'asc')
                    extWrt = 'asc';
                else
                    error('modVObs:unknownWrtTyp', ['The write type ' wrtGridTyp ' has not been programmed for.'])
                end

                %Write model output:
                pathOut = fullfile(dirWrite, [obsTypes{ii} '_grids'], [obsTypes{ii} '_mod.' extWrt]);
                [foldCurr, fileCurr, extCurr] = fileparts(pathOut);
                if ~isempty(wrtGridTyp)
                    if regexpbl(wrtGridTyp, {'nc', 'netcdf'})
                        if exist(pathOut, 'file')
                           delete(pathOut); 
                        end
                        print_grid_NC_v2(pathOut, gridModCurr, obsTypes{ii}, lon, lat, dateOut, dateBndsOut, unitCurr);
                    elseif regexpbl(wrtGridTyp, 'asc')
                        fileNmCurr = file_nm(fileCurr, 'ts', dateWrtOut);
                        
                        for kk = 1 : nDtCurr
                            pathOutCurr = fullfile(foldCurr, [fileNmCurr{kk}, extCurr]);
                            if exist(pathOutCurr, 'file')
                               delete(pathOutCurr); 
                            end
                            write_ESRI_v4(squeeze(gridModCurr(kk,:,:)), hdrOut, pathOutCurr, nDec); 
                        end
                    end
                end
                %Write time-cumulative grid:
                evalCurr = dataAll{indCurrType{ll},iMeta}{5};
                switch evalCurr
                    case 'mean'
                        gridWrt = squeeze(nanmean(gridModCurr, 1));
                    case 'sum'
                        gridWrt = squeeze(nansum(gridModCurr, 1));
                    case 'min'
                        gridWrt = squeeze(nanmin(gridModCurr, 1));
                    case 'max'
                        gridWrt = squeeze(nanmax(gridModCurr, 1));
                    otherwise
                        error('modVObs:unknownEvalType', ['The evaluation type ' dataAll{indCurrType{ll},iMeta}{5} ' is not known.']);
                end
                pathOutAvg = fullfile(dirWrite, [fileCurr, '_' evalCurr, '.asc']);
                write_ESRI_v4(gridWrt, hdrOut, pathOutAvg, nDec);
                
                %Write observed output:
                pathOut = fullfile(dirWrite, [obsTypes{ii} '_grids'], [obsTypes{ii} '_obs.' extWrt]);
                [foldCurr, fileCurr, extCurr] = fileparts(pathOut);
                if ~isempty(wrtGridTyp)
                    if regexpbl(wrtGridTyp, {'nc', 'netcdf'})
                        if exist(pathOut, 'file')
                           delete(pathOut); 
                        end
                        print_grid_NC_v2(pathOut, gridObsCurr, obsTypes{ii}, lon, lat, dateOut, dateBndsOut, unitCurr);
                    elseif regexpbl(wrtGridTyp, 'asc')
                        fileNmCurr = file_nm(fileCurr, 'ts', dateWrtOut);
                        
                        for kk = 1 : nDtCurr
                            pathOutCurr = fullfile(foldCurr, [fileNmCurr{kk}, extCurr]);
                            if exist(pathOutCurr, 'file')
                               delete(pathOutCurr); 
                            end
                            write_ESRI_v4(squeeze(gridObsCurr(kk,:,:)), hdrOut, pathOutCurr, nDec); 
                        end
                    end
                end
                %Write time-cumulative grid:
                switch evalCurr
                    case 'mean'
                        gridWrt = squeeze(nanmean(gridObsCurr, 1));
                    case 'sum'
                        gridWrt = squeeze(nansum(gridObsCurr, 1));
                    case 'min'
                        gridWrt = squeeze(nanmin(gridObsCurr, 1));
                    case 'max'
                        gridWrt = squeeze(nanmax(gridObsCurr, 1));
                    otherwise
                        error('modVObs:unknownEvalType', ['The evaluation type ' dataAll{indCurrType{ll},iMeta}{5} ' is not known.']);
                end
                pathOutAvg = fullfile(dirWrite, [fileCurr, '_' evalCurr, '.asc']);
                write_ESRI_v4(gridWrt, hdrOut, pathOutAvg, nDec);
                
                %Write level error:
                pathOut = fullfile(dirWrite, [obsTypes{ii} '_grids'], [obsTypes{ii} '_mod_minus_obs.' extWrt]);
                [foldCurr, fileCurr, extCurr] = fileparts(pathOut);
                if ~isempty(wrtGridTyp)
                    if regexpbl(wrtGridTyp, {'nc', 'netcdf'})
                        if exist(pathOut, 'file')
                           delete(pathOut); 
                        end
                        print_grid_NC_v2(pathOut, dataErrCurr, obsTypes{ii}, lon, lat, dateOut, dateBndsOut, unitCurr);
                    elseif regexpbl(wrtGridTyp, 'asc')
                        fileNmCurr = file_nm(fileCurr, 'ts', dateWrtOut);
                        
                        for kk = 1 : nDtCurr
                            pathOutCurr = fullfile(foldCurr, [fileNmCurr{kk}, extCurr]);
                            if exist(pathOutCurr, 'file')
                               delete(pathOutCurr); 
                            end
                            write_ESRI_v4(squeeze(dataErrCurr(kk,:,:)), hdrOut, pathOutCurr, nDec); 
                        end
                    end
                end
                %Write average:
                pathOutAvg = fullfile(dirWrite, [fileCurr, '_avg', '.asc']);
                write_ESRI_v4(squeeze(nanmean(dataErrCurr, 1)), hdrOut, pathOutAvg, nDec);
                
                %Write Percent Error:
                pathOut = fullfile(dirWrite, [obsTypes{ii} '_grids'], [obsTypes{ii} '_mod_percent_error.' extWrt]);
                [foldCurr, fileCurr, extCurr] = fileparts(pathOut);
                if ~isempty(wrtGridTyp)
                    if regexpbl(wrtGridTyp, {'nc', 'netcdf'})
                        if exist(pathOut, 'file')
                           delete(pathOut); 
                        end
                        print_grid_NC_v2(pathOut, dataMapeCurr, obsTypes{ii}, lon, lat, dateOut, dateBndsOut, unitCurr);
                    elseif regexpbl(wrtGridTyp, 'asc')
                        fileNmCurr = file_nm(fileCurr, 'ts', dateWrtOut);
                                          
                        for kk = 1 : nDtCurr
                            pathOutCurr = fullfile(foldCurr, [fileNmCurr{kk}, extCurr]);
                            if exist(pathOutCurr, 'file')
                               delete(pathOutCurr); 
                            end
                            write_ESRI_v4(squeeze(dataMapeCurr(kk,:,:)), hdrOut, pathOutCurr, nDec); 
                        end
                    end
                end
                %Write average:
                pathOutAvg = fullfile(dirWrite, [fileCurr, '_avg', '.asc']);
                write_ESRI_v4(squeeze(nanmean(dataMapeCurr, 1)), hdrOut, pathOutAvg, nDec);
            end %End of grid analysis
            

            %Time-series/Scatter plots (even of gridded data)
            nSeries = numel(indCurrType{ll});

            hFig = figure('Units','in','Position',[2 2 szFrame],'paperunits','in','paperposition',[2 2 szFrame]);
            whitebg([1,1,1]);
            set(hFig, 'color', 'white');
            hold on
            if flagScatter
                hTs = nan(nSeries,1);
                xMin = 0;
                xMax = 0;
                strSeries = cell(nSeries,1);
            else
                hTs = nan(2*nSeries,1);
                xMin = 10000;
                xMax = 0;
                strSeries = cell(2*nSeries,1);
            end

            %Set colors:
            if nSeries <= 4
                colorsUse = clrBrewer;
            else
                colorsUse = distinguishable_colors(nSeries);
            end

            %Plot each series for the given data type:
            for indCurr = 1 : nSeries
                if flagScatter %Display data as scatter plot, otherwise make time-series
                    if numel(size(dataAll{indCurrType{ll}(indCurr),iMData})) == 2
                        plotModData  = dataAll{indCurrType{ll}(indCurr),iMData};
                    elseif numel(size(dataAll{indCurrType{ll}(indCurr),iMData})) == 3
                        plotModData = nan(numel(dataAll{indCurrType{ll}(indCurr),iMData}(:,1,1)),1);
                        for mm = 1 : numel(dataAll{indCurrType{ll}(indCurr),iMData}(:,1,1))
                            plotModData(mm)  = mean2d(squeeze(dataAll{indCurrType{ll}(indCurr),iMData}(mm,:,:)));
                        end
                    end
                    if numel(size(dataAll{indCurrType{ll}(indCurr),iOData})) == 2
                        plotObsData  = dataAll{indCurrType{ll}(indCurr),iOData};
                    elseif numel(size(dataAll{indCurrType{ll}(indCurr),iOData})) == 3
                        plotObsData = nan(numel(dataAll{indCurrType{ll}(indCurr),iOData}(:,1,1)),1);
                        for mm = 1 : numel(dataAll{indCurrType{ll}(indCurr),iOData}(:,1,1))
                            plotObsData(mm)  = mean2d(squeeze(dataAll{indCurrType{ll}(indCurr),iOData}(mm,:,:)));
                        end
                    end

                    hTs(indCurr) = scatter(plotObsData,plotModData, ...
                        2*ftSz, 'MarkerEdgeColor',[0 0 0], 'MarkerFaceColor',colorsUse(mod(indCurr-1, nSeries)+1,:));
                    xMin = min(min(real([dataAll{indCurrType{ll}(indCurr),iMData}(:); dataAll{indCurrType{ll}(indCurr),iOData}(:)])), xMin);
                    xMax = max(max(real([dataAll{indCurrType{ll}(indCurr),iMData}(:); dataAll{indCurrType{ll}(indCurr),iOData}(:)])), xMax);

                    %Create legend entries:
                    lgdCurr = dataAll{indCurrType{ll}(indCurr),iMeta}{3};
                    if ischar(lgdCurr)
                        if regexpbl(lgdCurr, {'all', 'avg'})
                            strSeries{indCurr} = 'Grid Mean';
                        else
                            error('modVObs:gridLabel', [lgdCurr ' is not a recognized observation location labeling option.']);
                        end
                    elseif isnumeric(lgdCurr)
                        strSeries{indCurr} = ['Pt (' num2str(round2(lgdCurr(1),3)) ', ' num2str(round2(lgdCurr(2),3)) ')'];
                    else
                        error('modVObs:gridLabelClass', [class(lgdCurr) ' is not a recognized format for the observation location label.']);
                    end
                    
                else %time-series without linear time-step increases (such as glacier stakes)
                    cntrTs = 2*(indCurr-1) + 1 : 2*indCurr;

                    if iscell(dataAll{indCurrType{ll}(indCurr),iMDate})
                        plotDates = [];
                        plotModData  = [];
                        plotObsData  = [];
                        for kk = 1 : numel(dataAll{indCurrType{ll}(indCurr),iMDate}{1})
                            tempModDates = (dataAll{indCurrType{ll}(indCurr),iMDate}{1}(kk) : dataAll{indCurrType{ll}(indCurr),iMDate}{2}(kk));
                            plotDates = [plotDates, tempModDates];
                            if numel(size(dataAll{indCurrType{ll}(indCurr),iMData})) == 2
                                plotModData  = [plotModData, dataAll{indCurrType{ll}(indCurr),iMData}(kk)*ones(1, numel(tempModDates))];
                            elseif numel(size(dataAll{indCurrType{ll}(indCurr),iMData})) == 3
                                plotModData  = [plotModData, mean2d(squeeze(dataAll{indCurrType{ll}(indCurr),iMData}(kk,:,:)))*ones(1, numel(tempModDates))];
                            end
                            if numel(size(dataAll{indCurrType{ll}(indCurr),iOData})) == 2
                                plotObsData  = [plotObsData, dataAll{indCurrType{ll}(indCurr),iOData}(kk)*ones(1, numel(tempModDates))];
                            elseif numel(size(dataAll{indCurrType{ll}(indCurr),iOData})) == 3
                                plotObsData  = [plotObsData, mean2d(squeeze(dataAll{indCurrType{ll}(indCurr),iOData}(kk,:,:)))*ones(1, numel(tempModDates))];
                            end

                        end

                        hTs(cntrTs)= plot(plotDates, plotModData, 'x', plotDates, plotObsData, 'o'); 

                        %Find min and max dates:
                        xMin = min(min(plotDates), xMin);
                        xMax = max(max(plotDates), xMax);
                    else %Regular time-series
                        hTs(cntrTs)= plot(dataAll{indCurrType{ll}(indCurr),iMDate}, dataAll{indCurrType{ll}(indCurr),iMData}, '-x', dataAll{indCurrType{ll}(indCurr),iODate}, dataAll{indCurrType{ll}(indCurr),iOData}, '-o'); 

                        %Find min and max dates:
                        xMin = min(dataAll{indCurrType{ll}(indCurr),iMDate}(1), xMin);
                        xMax = max(dataAll{indCurrType{ll}(indCurr),iMDate}(end), xMax);
                    end

                    %Set properties of current series:
                    set(hTs(cntrTs(1)),'Color',([0.5,0.5,0.5] + 0.5*colorsUse(mod(indCurr-1, nSeries)+1,:)),'LineWidth',lnWdA);
                    set(hTs(cntrTs(2)), 'Color',colorsUse(mod(indCurr-1, nSeries)+1,:));

                    %Create legend entries:
                    lgdCurr = dataAll{indCurrType{ll}(indCurr),iMeta}{3};
                    if ischar(lgdCurr)
                        if regexpbl(lgdCurr, {'all', 'avg'})
                            strCurrPt = 'Grid Mean';
                        else
                            error('modVObs:gridLabel', [lgdCurr ' is not a recognized observation location labeling option.']);
                        end
                    elseif isnumeric(lgdCurr)
                        strCurrPt = ['Pt (' num2str(round2(lgdCurr(1),3)) ', ' num2str(round2(lgdCurr(2),3)) ')'];
                    else
                        error('modVObs:gridLabelClass', [class(lgdCurr) ' is not a recognized format for the observation location label.']);
                    end
                    
                    %strCurrPt = ['Pt (' num2str(round2(dataAll{indCurrType{ll}(indCurr),indMeta}{3}(1),3)) ', ' num2str(round2(dataAll{indCurrType{ll}(indCurr),indMeta}{3}(2),3)) ')'];
                    strSeries(cntrTs(1):cntrTs(2)) = {['Mod @ ' strCurrPt]; ['Obs @ ' strCurrPt]};
                end
            end

            if xMax == Inf || (exist('yMax','var') && yMax == Inf)
                h = gcf;
                axesObjs = get(h, 'Children');  %axes handles
                dataObjs = get(axesObjs, 'Children'); %handles to low-level graphics objects in axes

                xdata = get(dataObjs, 'XData');  %data from low-level grahics objects
                ydata = get(dataObjs, 'YData');

                xMax = 0;
                for zz = 1 : numel(xdata)
                    indNInf = find(xdata{zz} ~= Inf);
                    if ~isempty(indNInf)
                       xMax = max([xMax,xdata{zz}(indNInf)]); 
                    end
                end

                yMax = 0;
                for zz = 1 : numel(ydata)
                    indNInf = find(ydata{zz} ~= Inf);
                    if ~isempty(indNInf)
                       yMax = max([yMax,ydata{zz}(indNInf)]); 
                    end
                end
            end

            if flagScatter
                xlim(real([xMin,xMax]));
                ylim(real([xMin,xMax]));

                %Add reference line(s)
                hRef(1) = line([xMin xMax],[xMin xMax]);

                %Add text tag:
                yMin = ylim;
                    yMax = yMin(2);
                    yMin = yMin(1);

                if xMin < 0
                    hRef(2) = line([xMin xMax],[0 0]);
                    hRef(3) = line([0 0], [yMin yMax]);

                    hText(1) = text(double(0.015*(xMax-xMin) + xMin), double(0.95*(yMax-yMin) + yMin),'Model Overpredicts');
                    hText(2) = text(double( 0.73*(xMax-xMin) + xMin), double(0.68*(yMax-yMin) + yMin),'Model Underpredicts');

                    hText(3) = text(double(0.015*(xMax-xMin) + xMin), double(0.32*(yMax-yMin) + yMin),'Model Underpredicts');
                    hText(4) = text(double( 0.73*(xMax-xMin) + xMin), double(0.07*(yMax-yMin) + yMin),'Model Overpredicts');
                else
                    hText(1) = text(double(0.05*(xMax-xMin) + xMin), double(0.95*(yMax-yMin) + yMin),'Model Overpredicts');
                    hText(2) = text(double( 0.7*(xMax-xMin) + xMin), double(0.07*(yMax-yMin) + yMin),'Model Underpredicts');
                end


                %Set Labels:
                hXLab = xlabel(['Observed (' unitCurr ')']);
                hYLab = ylabel(['Modelled (' unitCurr ')']);

                %Set labels
                if xMax - xMin + 1 <= 10
                    ptsTicks = (xMin:1:xMax);

%                     nXTicks = xMax - xMin + 1;
%                     ptsTicks =  round(linspace(xMin,xMax,nXTicks));
                elseif xMax - xMin + 1 <= 20                    
                    ptsTicks = (xMin:2:xMax);

%                     nXTicks = xMax - xMin + 1;
%                     ptsTicks =  round(linspace(xMin,xMax,nXTicks));
                elseif xMax - xMin + 1 <= 40
                    ptsTicks = (xMin:4:xMax);
                elseif xMax - xMin + 1 <= 60
                    ptsTicks = (xMin:6:xMax);
                elseif xMax - xMin + 1 <= 80
                    ptsTicks = (xMin:8:xMax);
                elseif xMax - xMin + 1 <= 100
                    ptsTicks = (xMin:10:xMax);
                else
                    nXTicks = 12;
                    ptsTicks =  round(linspace(xMin,xMax,nXTicks));
                end

                set(gca, 'XTickLabel', round2(ptsTicks,1), 'XTick', ptsTicks);
                set(gca, 'YTickLabel', round2(ptsTicks,1), 'YTick', ptsTicks);


            else
                hRef = line([xMin xMax],[0 0]);

                %Set Labels:
                hXLab = xlabel('Date');
                hYLab = ylabel([varCurr ' (' unitCurr ')']);

                %EDIT X-TICK LABELS:
                xMin = max(xMin, 1);
                %Create dates for x-axis:
                strDates = date2str(unique(days_2_date_v2((xMin:xMax),dataAll{indCurrType{ll}(indCurr),iMeta}{2}(1,:),'gregorian'),'rows'),'m/d/y');
                %Set labels
                if ischar(strDates)
                    nXTicks = 1;
                else
                    nXTicks = min(numel(strDates),10);
                end
                ptsDates = round(linspace(1,numel(strDates),nXTicks));
                ptsTicks =  round(linspace(xMin,xMax,nXTicks));
                set(gca, 'XTickLabel',strDates(ptsDates), 'XTick', ptsTicks);
                set(gca, 'XTickLabelRotation', 45);
                %Set axis and data fram properties:
                xlim([xMin-5,xMax+5]); 
            end
            hold off

            %Create Legend:
            hLgd = legend(hTs,strSeries,'location','bestoutside');


            %Set plot properties:
            set(gca, ...
                'FontName'   , strFont);
            set([hXLab, hYLab], ...
                'FontName'   , strFont);
            set(hLgd, ...
                'FontSize'   , ftSzLgd, ...
                'LineWidth', lnWdA);
            set([hXLab, hYLab]  , ...
                'FontSize'   , ftSz, ...
                'Color', 'black');
            set(hRef(:),'LineWidth', lnWd, ...
                'LineStyle','--', ...
                'color',custGray);
            set(gca, ...
                'Box'         , 'off', ...
                'TickDir'     , 'in'     , ...
                'TickLength'  , [.02 .02] , ...
                'LineWidth'   , lnWdA , ...
                'fontSize', ftSzAx);   
            if ~flagScatter
                set(gca, 'YMinorTick'  , 'on');
            else
                set(hText, ...
                    'FontSize'   , ftSzLgd, ...
                    'LineWidth', lnWdA);
            end

            if isdir(outputPath)
                dirWrite = outputPath;
                fileWrite = '';
            else
                [dirWrite, fileWrite, ~]= fileparts(outputPath);
            end
            if ~isempty(fileWrite)
                pathWrite = fullfile(dirWrite, [fileWrite '_' num2str(ii)]);
            else
                pathWrite = fullfile(dirWrite, ['mod_v_obs_' num2str(ii)]);
            end

            if flagScatter
                pathWrite = [char(pathWrite), '_scatter'];
            else
                pathWrite = [char(pathWrite), '_ts'];
            end

            savefig(hFig, [pathWrite '.fig']);
            print(hFig, [pathWrite '.eps'],'-depsc2');
            print(hFig, [pathWrite '.png'],'-dpng','-r600');
        end
    end
end

if nargout >= 1
    varargout{1} = scoreOut; 
	if nargout == 2
        for kk = 1 : nMetric
            %Rename specific obsure output names:
            for ii = 1 : numel(nmScore{kk}(:))
                if regexpbl(nmScore{kk}{ii}, 'casi')
                   nmScore{kk}{ii} = 'cryosphere covered area'; 
                end
            end
        end
    	varargout{2} = nmScore;
	end
end
