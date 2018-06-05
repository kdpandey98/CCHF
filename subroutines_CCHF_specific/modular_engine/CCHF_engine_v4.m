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

function varargout = CCHF_engine_v4(sPath, sHydro, sMeta, varargin)


%'sMeta' is a structure array describing data properties:
    %'currVar' = current variable to load
    %'metVar' = Cell array of all variables requested
    %'metVarDisp' = Cell array of display names for all variables
        %requested
    %'hisTS' = 'GPCC', 'CRU', or 'Willmott'
    %'hisTSDisp' = full version of entry in 'sMeta.hisTS'
    %'yrsOut' = [first year of output data, last year of output data]
    %'yrsClim' = [first year of climatology, last year of climatology]
    %'mnths' = list of months requested
    %'crd' = [lonW, lonE, latS, latN]
    %'dateCurr' = [year, month, day, hour]  - subdivisons depend on time
        %step
%'sHydro{mm}' is a structure array describing downscaling characteristics:
    %'sHydro{mm}.dem' =  
    %'sHydro{mm}.fdr' =  
    %'glacier' =  
    %'lat' = 
    %'lon' = 
%'sPath{mm}' is a sctructure array with all the paths to necessary data inputs:
%(Many of these fields are cells, allowing them to store all path strings if 
%multiple variables being downscaled)
    %'hisTS' = path of 0.5 degree monthly time-series input
    %'hisGCM' = path of historical GCM run (only used in downscaling GCM
        %data)
    %'hrClim' = path of 30-arcsecond climatology (i.e. WorldClim)
    %'futTS' = path of projected GCM run (only used in downscaling GCM
        %data)
    %'regClip' = path of boolean data used to clip downscaled outputs (can
        %be empty)
    %'output' = output path


varLat = 'latitude';
varLon = 'longitude';
    
%%Set default values:
%This value simply determines when to test the fitness of the current
%parameter set. Early convergence is allowed if does not meet fitness
%requirement. Default value is huge, then is edited below.
indEval = 10^6;
fitTest = 'KGE';
dateEval = sMeta.dateRun(end,:);
fitReq = 100;
blEval = 0;
evalAtt = cell(0,0);

%Define number of model runs based on inputs:
nSites = numel(sPath(:));

%If model being run in parameter mode, only run for one site:
if regexpbl(sMeta.mode,'parameter')
    nSites = 1;
end

%Initialize arrays:
sOutput = cell(nSites, 1);
    [sOutput{:}] = deal(struct);
sObs = sOutput;
modError = nan(nSites, 1);

%Used to determine if coefficients loaded from variable input arguments
blCfVar = 0;
pathOut = '';

%Parse additional variable input arguments
if ~isempty(varargin(:)) && numel(varargin(:)) > 0
    for ii = 1 : numel(varargin(:))
%             if isnumeric(varargin{ii}) && all(~isnan(varargin{ii}))
%                 varargin{ii} = num2cell(squeeze(varargin{ii}));
%             end
        if regexpbl(varargin{ii}, {'cf', 'coef'})
            cfTmp = varargin{ii+1};
            if isnumeric(cfTmp)
                cfTmp = num2cell(cfTmp);
            end
            if ~isequal(size(sMeta.coefAtt(:,1)), size(cfTmp(:)))
                error('cchfEngine:cfDiffSz',['The cf attribute matrix has ' ...
                    num2str(numel(sMeta.coefAtt(:,1))) ' entries and '...
                    'the input cf matrix has ' num2str(numel(cfTmp)) ' entries.']);
            end
            sMeta.coef = [sMeta.coefAtt(:,1), cfTmp(:)];
            blCfVar = 1;
        elseif regexpbl(varargin{ii}, 'obs')
            sObs = varargin{ii+1};
        elseif regexpbl(varargin{ii}, 'path')
            pathOut = varargin{ii+1};
        elseif regexpbl(varargin{ii}, {'eval','att'})
            evalAtt = varargin{ii+1};
        end

%             if isfield(sMeta,'coefAtt') && isequal(size(sMeta.coefAtt(:,1)), size(squeeze(varargin{ii}(:))))
%                 sMeta.coef = [sMeta.coefAtt(:,1), varargin{ii}(:)];
%                 blCfVar = 1;
%             elseif isfield(sMeta,'coef') && numel(sMeta.coef(:,1)) == numel(squeeze(varargin{ii})) && ischar(sMeta.coef{ii})
%                 sMeta.coef = [sMeta.coef(:,1), varargin{ii}(:)];
%                 blCfVar = 1;
%             elseif iscell(varargin{ii}) 
%                 if isstruct(varargin{ii}{1})
%                     sObs = varargin{ii};
%                 elseif ~any(size(varargin{ii}) == 1) && ischar(varargin{ii}{1,1}) && ischar(varargin{ii}{2,1})
%                     evalAtt = varargin{ii};
%                 end
%             elseif ischar(varargin{ii}) && regexpbl(varargin{ii}, 'path')
%                 pathOut = varargin{ii+1};
% %                 error('backbone:varargTyoe',['Variable argument 2 '...
% %                     'must be structure of observations and 3 must '...
% %                     'be cell array with evaluation attributes.']);
%             end
    end

    if ~isempty(evalAtt)
        fitTest  = find_att(evalAtt, 'fitTest');
        dateEval = find_att(evalAtt, 'dateEval');
        fitReq   = find_att(evalAtt, 'fitReq');
    end
    if numel(sMeta.dateRun(1,:)) > numel(dateEval)
        dateEval = [dateEval, ones(1, numel(sMeta.dateRun(1,:)) - numel(dateEval))];
    elseif numel(sMeta.dateRun(1,:)) < numel(dateEval)
        dateEval = dateEval(1:numel(sMeta.dateRun(1,:)));
    end
    indEval = find(ismember(sMeta.dateRun, dateEval, 'rows') == 1);
    if isempty(indEval)
        strDateEval = blanks(0);
        for kk = 1 : numel(dateEval)
            strDateEval = [strDateEval, num2str(dateEval(kk))];
            if kk ~= numel(dateEval)
                strDateEval = [strDateEval, '-'];
            end
        end
       error('backbone:dateMismatch',['The dateEval, ' ...
           strDateEval ', does not match any of the dates the model will be run for.']); 
    end
end


%Implement options only used in non-parameter finding runs
if ~regexpbl(sMeta.mode,'parameter')
    if ~isfield(sMeta,'dateRun')
        sMeta = dates_run(sMeta,'spin');
    end
      
    %If coefficient parameter set given as variable input argument, override
    %parameters in sMeta.
    if blCfVar == 0
        if isfield(sMeta,'coef')
            if numel(sMeta.coef(1,:)) < 2 || numel(sMeta.coef(1,:)) > 4
                error('CCHF_backbone:coefHydroDim',[char(39) 'sMeta.coef' char(39)...
                    ' has an unexpected number of columns.']);
            end
        elseif isfield(sMeta,'coefAtt')
            if numel(sMeta.coefAtt(1,:)) == 5
                sMeta.coef = sMeta.coefAtt(:,[1,4]);
            else
                error('CCHF_backbone:coefattHydroDim',[char(39) 'sMeta.coefAtt' char(39)...
                    ' has an unexpected number of columns.']);
            end
        else
            error('CCHF_backbone:noCoef1',['No input field containing '...
                'the requisite model parameters was found.']);
        end
    elseif blCfVar == 1 
        if ~isfield(sMeta, 'coef') 
            error('CCHF_backbone:noCoefField',['Variable input argument being ' ...
                'used to assign parameter values, but neither ' char(39) ...
                'sMeta.coef' char(39) ' does not exist.']);
        elseif any2d(size(sMeta.coef) == 1)
            error('CCHF_backbone:coefWrongSize',['Variable input argument being ' ...
                'used to assign parameter values, but appears to be missing a column (either parameter names or values)']);
            
        elseif any(isnan(cell2mat(sMeta.coef(:,2))))
            error('CCHF_backbone:coefNan',['Variable input argument being ' ...
                'used to assign parameter values, but ' char(39) ...
                'sMeta.coef' char(39) ' has at least one nan value.']);
        end
    end
        
    if isempty(sMeta.coef)
        error('CCHF_backbone:coefEmpty',['An input parameter field was found but '...
            'it is empty.']);
    end
end


%Loop over study sites:
for mm = 1 : nSites
    sMeta.siteCurr = mm;
    
    [foldTemp, ~, ~] = fileparts(sPath{mm}.dem);
    sMeta.foldstorage = fullfile(foldTemp, 'model_process_storage');
    
    %Declare global variables (must clear them because model run in parallel)
    if ~regexpbl(sMeta.runType,'sim') %Don't clear land structure array if running simulation (may be dangerous but saves multiple hours for large grids)
        clear global sLand %Possibly simply initialize instead of clearing
    end

    clear global sAtm sCryo
    global sAtm sCryo sLand
    sLand.indCurr = 1; %Necessary if sLand not cleared above.
    
    
    if regexpbl(sMeta.mode,'parameter') && mm == 1
        disp(['The CCHF model is being run in ' char(39) sMeta.mode char(39) ' mode.']);
        %Define date vector of time steps to loop over:
        if regexpbl(sMeta.dt,'month')
            sMeta.dateRun = nan(1,2);
        elseif regexpbl(sMeta.dt,{'day','daily'})
            sMeta.dateRun = nan(1,3);
        elseif regexpbl(sMeta.dt,'hour')
            sMeta.dateRun = nan(1,4);
        else
            error('backbone:dtUnknown',[sMeta.dt ' is an unknown time-step']);
        end

        %Remove 'progress' field from sMeta if parameter run.
        sMeta = rmfield_x(sMeta, 'progress');

        %Initialize coef argument for assigning parameters to:
        coef = cell(0,6);
    elseif ~regexpbl(sMeta.mode,'parameter')    
        %Determine when to start recording output:
        sMeta.indWrite = find(all(sMeta.dateRun == repmat(sMeta.dateStart, numel(sMeta.dateRun(:,1)),1),2) == 1);

        %Determine if climate input files have been clipped and aligned to
        %input DEM (if so, code field that will expedite loading process):
        for ll = 1 : numel(sMeta.varLd) 
            if ~isfield(sPath{mm}, sMeta.varLd{ll}) || isempty(sPath{mm}.(sMeta.varLd{ll}))
                continue
            end

            if regexpbl(sPath{mm}.([sMeta.varLd{ll} 'File']){1},'.nc')
                lonTemp = ncread(sPath{mm}.([sMeta.varLd{ll} 'File']){1},'lon')';
                latTemp = ncread(sPath{mm}.([sMeta.varLd{ll} 'File']){1},'lat');
            elseif regexpbl(sPath{mm}.([sMeta.varLd{ll} 'File']){1},{'.asc','.txt'})
                [~,hdrESRI,hdrMeta] = read_ESRI(sPath{mm}.([sMeta.varLd{ll} 'File']){1});
                [latTemp, lonTemp] = ESRI_hdr2geo(hdrESRI,hdrMeta);
            else
                error('backbone:unkownFileType','The present file type has not been coded for.');
            end

            if isequal(round2(latTemp,4),round2(sHydro{mm}.(varLat),4)) && isequal(round2(lonTemp,4),round2(sHydro{mm}.(varLon),4 ))
                if ~isfield(sPath{mm},'varNm')
                    sPath{mm}.varNm = cell(size(sMeta.varLd));
                end
                if isempty(sPath{mm}.varNm{ll})
                    if regexpbl(sPath{mm}.([sMeta.varLd{ll} 'File']){1},'.nc')
                        nmVarTemp = ncinfo(sPath{mm}.([sMeta.varLd{ll} 'File']){1});
                        nmVarTemp = squeeze(struct2cell(nmVarTemp.Variables(:)));
                        nmVarTemp = nmVarTemp(1,:)';
                            nmVarTemp(strcmpi(nmVarTemp,'lon')) = [];
                            nmVarTemp(strcmpi(nmVarTemp,'longitude')) = [];
                            nmVarTemp(strcmpi(nmVarTemp,'lat')) = [];
                            nmVarTemp(strcmpi(nmVarTemp,'latitude')) = [];
                            nmVarTemp(strcmpi(nmVarTemp,'time')) = [];
                            nmVarTemp(strcmpi(nmVarTemp,'time_bnds')) = [];
                        if numel(nmVarTemp) == 1
                            sPath{mm}.varNm{ll} = nmVarTemp{1};
                        end
                    elseif regexpbl(sPath{mm}.([sMeta.varLd{ll} 'File']){1},{'.asc','.txt'})
                        if regexpbl(sPath{mm}.([sMeta.varLd{ll} 'File']){1},{'pr'})
                            varTmp = 'pr';
                        elseif regexpbl(sPath{mm}.([sMeta.varLd{ll} 'File']){1},{'tmin','tmn','tasmin'})
                            varTmp = 'tasmin';
                        elseif regexpbl(sPath{mm}.([sMeta.varLd{ll} 'File']){1},{'tmax','tmx','tasmax'})
                            varTmp = 'tasmax';
                        elseif regexpbl(sPath{mm}.([sMeta.varLd{ll} 'File']){1},{'tmean','tmp'})
                            varTmp = 'tas';
                        else
                            error('backbone:varDetect',['The variable associated with the file: ' ...
                                sPath{mm}.([sMeta.varLd{ll} 'File']){1} ' is unknown.']);
                        end
                        sPath{mm}.varNm{ll} = varTmp;
                    end
                end
            end
        end

        %Determine resolution of hydro grid and store in sMeta:
        sMeta.spRes = nanmean([nanmean(abs(diff(sHydro{mm}.(varLat)))), nanmean(abs(diff(sHydro{mm}.(varLon))))]);
        sMeta.spEps = 0.1*sMeta.spRes;

        sMeta.frame = 0;
    end

    %progress update option in sMeta:
    if isfield(sMeta,'progress')
        if regexpbl(sMeta.progress,{'year', 'yr'})
            indEnd = 1;
        elseif regexpbl(sMeta.progress,{'month', 'mnth'})
            indEnd = 2;
        elseif regexpbl(sMeta.progress,{'day', 'dy'})
            indEnd = 3;
        elseif regexpbl(sMeta.progress,{'hour', 'hr'})
            indEnd = 4;
        else
            warning('backbone:progressUnknown',['No progress update will be given because ' ...
                sMeta.progress ' is not recognized.'])
        end

        uniqTs = unique(sMeta.dateRun(:,1:indEnd),'rows');

        sMeta.indUpdate = nan(numel(uniqTs(:,1)),1);
        for zz = 1 : numel(uniqTs(:,1))
            sMeta.indUpdate(zz) = find(ismember(sMeta.dateRun(:,1:indEnd), uniqTs(zz,1:indEnd), 'rows') == 1, 1, 'first');
        end
    end



    szDem = size(sHydro{mm}.dem);
    nTS  = numel(sMeta.dateRun(:,1));


    %Enter time loop:
    for ii = 1 : nTS
        sMeta.dateCurr = sMeta.dateRun(ii,:);
        sMeta.indCurr = ii;
    %     disp(['iteration ' num2str(ii) ' of ' num2str(numel(sMeta.dateRun(:,1)))]);

        if isfield(sMeta, 'indUpdate')
            if any(ii == sMeta.indUpdate)
                disp(['CCHF model is on time step '...
                    num2str(ii) ' of ' num2str(nTS) ' (site ' ...
                    num2str(mm) ' of ' num2str(nSites) ').']);
            end
        end

        %%LOAD TIME-SERIES CLIMATE DATA:
        if isequal(sMeta.dt,sMeta.dataTsRes) %climate time step and model time step are same
            load_climate_v2(sPath{mm}, sHydro{mm}, sMeta);
        else %time steps different (in some cases, this may be able to 
            if ii == 1
               sInput = struct; 
            end
            sInput = load_climate_v2(sPath{mm}, sHydro{mm}, sMeta, sInput);
        end


        %Initialize cryosphere and land arrays:
        if ii == 1   
            %Define edges of main grid and record in sMeta (useful for limiting data loaded using 'geodata'):
            edgeLat = box_edg(sHydro{mm}.(varLat));
            edgeLon = box_edg(sHydro{mm}.(varLon));

            sMeta.crd = [edgeLon(1), edgeLon(end), edgeLat(end), edgeLat(1)]; %[W, E, S, N]


            %Initialize cryosphere structure:
            sCryo = rmfield_x(sAtm,{'data','pr','pre','tas','tasmin','tmin','tmn','tmax','tasmax','tmx','lat','lon'});

            %INITIALIZE ICE GRID
            %Load glacier coverage data and convert to depth:
            if isfield(sHydro{mm}, 'sIceInit')
                %Define seperate ice spatial grid if path defined
                nmIce = fieldnames(sHydro{mm}.sIceInit);
                for iIce = 1 : numel(nmIce)
                    sCryo.(nmIce{iIce}) = sHydro{mm}.sIceInit.(nmIce{iIce});
                end
                if issparse(sCryo.icx)
                    sCryo.icx = full(sCryo.icx);
                end
            else
                error('cchfEngine:noIceGrid','No ice grid available. This should have been created in the main script.');
                %sHydro{mm}.icbl = ice_grid_init(sHydro{mm}, sPath{mm}, sMeta);
            end
            %Set date (month/day) when glacier mass balance will be
            %processed.
            if all(~isnan(sMeta.dateStart))
                dateTemp = days_2_date_v2(-1, sMeta.dateStart, 'gregorian');
                sMeta.dateGlac = dateTemp(2:end);
            else
                sMeta.dateGlac = nan(size(sMeta.dateStart));
                warning('cchfEngine:dateStartNan','The start date vector contains nan values. This is not allowed.');
            end


            %Initialize solid snow depth (water equivalent) grid
            sCryo.snw = zeros(size(sHydro{mm}.dem),'single');

            %initialize snow internal temperature:
            if regexpbl(sMeta.coef, 'tsn')
                sCryo.tsn  = nan(size(sCryo.snw),'single'); 
                sCryo.tsis = nan(size(sCryo.snw),'single');
            end



            %%INITIALIZE LAND ARRAY (for vegetation cover - if used, soil
            %moisture, runoff, flow, etc.)
            sLand = rmfield_x(sAtm,{'data','pr','pre','tas','tasmin','tmin','tmn','tmax','tasmax','tmx','lat','lon','time','attTime','indCurr'});

            sLand.mrro = zeros(szDem,'single'); %runoff out of each cell
            sLand.flow = zeros(szDem,'single'); %flowrate at each cell
            sLand.sm   = zeros(szDem,'single'); %Soil moisture field
            sLand.et   = zeros(szDem,'single'); %evapotranspiration field
        end

    %%DO EVERY ITERATION:
        %Reset some fields every iteration:
        sLand.mrro = zeros(szDem,'single'); %runoff out of each cell

        if isfield(sCryo,'ice')
            sCryo.icdwe = zeros(szDem,'single');
        else
            sCryo.icdwe = nan(szDem,'single');
        end
        sCryo.sndwe = zeros(szDem,'single');


%         %UPDATE TIME INDICES for sAtm (potentially used when loading climate
%         %inputs)
%         if ~regexpbl(sMeta.mode,'parameter')
%             [sAtm.indCurr, ~] = geodata_time_ind(sAtm, sMeta.dateRun(ii,:));
%         end

    %%FITTING PARAMETERS FOR PRE AND TMP:
    %     if regexpbl(sMeta.mode,'parameter')
    %         coef = cat(1,coef,{'cfPre', 0.1, 10, 4.0, 'backbone','input'});
    %     else
    %         cfPre = find_att(sMeta.coef,'cfPre');
    %         sAtm.pr = cfPre*sAtm.pr;
    %     end
    %     if regexpbl(sMeta.mode,'parameter')
    %         coef = cat(1,coef,{'cfTmp', -5, 5, 1.50, 'backbone','input'});
    %     else
    %         cfTmp = find_att(sMeta.coef,'cfTmp');
    %         sAtm.tas = cfTmp + sAtm.tas;
    %     end

        %Allow katabatic scaling of temperature over glaciers:
            %Katabatic wind (cooling effect over glaciers; see Shea and Moore, 
            %2010 or Alaya, Pellicciotti, and Shea 2015 for more complex models):
    %     if regexpbl(sMeta.mode,'parameter')
    %         coef = cat(1,coef,{'cfKat', -6, 0, -2.75, 'backbone','input'});
    %     else
    %         cfKat = find_att(sMeta.coef,'cfKat');
    % 
    %         indIce = find(sCryo.ice > 0);
    %         szTmp = size(sAtm.tas);
    %         [tIce,~] = meshgrid((1:szTmp(1)),(1:numel(indIce)));
    %         [rIce, cIce] = ind2sub(szTmp(2:3),indIce);
    %         [~,rIce] = meshgrid((1:szTmp(1)),rIce);
    %         [~,cIce] = meshgrid((1:szTmp(1)),cIce);
    %         indIce = tIce + (rIce-1)*szTmp(1) + (cIce-1)*szTmp(2)*szTmp(1);
    % 
    %         sAtm.tas(indIce) = sAtm.tas(indIce) + cfKat;
    %     end



    %%IMPLEMENT MODULES:
        if regexpbl(sMeta.mode,'parameter')
            coefTemp = cat(1,coef, CCHF_modules(sHydro{mm}, sMeta));
            %In case there are coefficients with dependencies, need to
            %iterate coefficient search.
            %Currently the only case of this is snowpack temperature, which is
            %dealt with here: 
            if regexpbl(coefTemp(:,1), 'tsn')
                sCryo.tsn = nan(size(sHydro{mm}.dem)); %This line is necessary to access some snow temperature dependent fitting parameters
                coef = cat(1,coef, CCHF_modules(sHydro{mm}, sMeta));
                indRem = strcmpi(coef(:,1),'tsn');
                coef(indRem,:) = []; 
            else
                coef = coefTemp;
            end
        else
            CCHF_modules(sHydro{mm}, sMeta);
            %Check conservation of energy and mass:
%             CCHF_conservation(sMeta);
        end




    %%FIND AND WRITE OUTPUT FIELDS:
        if isfield(sMeta,'output') && ~regexpbl(sMeta.mode,'parameter') && ii >= sMeta.indWrite
            %Only tranasfer output structure array from 'print_model_state'
            %to this function on select time steps because it is very slow.
            if any(sMeta.indCurr == indEval) || sMeta.indCurr == nTS
                sOutput{mm} = print_model_state_v4(sHydro{mm}, sMeta, sPath{mm}.output); 
            else
                print_model_state_v4(sHydro{mm}, sMeta, sPath{mm}.output); 
            end
%            sOutput{mm} = print_model_state_v4(sHydro{mm}, sMeta, sPath{mm}.output); 
        end

    %%ALLOW EARLY TERMINATION IF CALIBRATION AND REPRESENTATIVE PERIOD HAS BEEN
    %%SURVEYED
        if ii > indEval && ~isempty(fieldnames(sObs{mm})) && blEval == 0
            blEval = 1;
            modErrorTemp = nanmean(mod_v_obs_v2(sObs{mm}, sOutput{mm}, fitTest, 'combineType', 'rmMod'));
            if modErrorTemp > fitReq %Quit early
                modError(mm) = modErrorTemp;
                break
            end
        end
    end
end


%%assign information to output arguments:
if regexpbl(sMeta.mode,'parameter')
    varargout{1} = coef(~cellfun(@isempty, coef(:,1)),:);
else
    varargout{1} = sOutput;
    if nargout > 1 %Will be nan if short analysis not option or if met fitness requirement during short analysis.
        varargout{2} = modError;
    end
    
    if ~isempty(pathOut)
        if ischar(pathOut)
            pathOut = {pathOut};
        end

        for ii = 1 : numel(sOutput)
            if numel(pathOut(:)) == numel(sOutput(:))
                pathOutRt = pathOut{ii};
            elseif numel(pathOut(:)) == 1
                pathOutRt = pathOut{1};
            else
                error('CCHFMain:pathOutSize','Path out was selected but has an unknown size.')
            end
            [fold,file,ext] = fileparts(pathOutRt);
            if ~exist(fold, 'dir')
               mkdir(fol);
            end
            if isempty(ext)
                ext = '.mat';
            end
            pathOutCurr = fullfile(fold, [file '_' sMeta.region{ii} ext]);
            output = sOutput{ii};
            save(pathOutCurr, 'output');
        end
    end
end
