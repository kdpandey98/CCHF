function argout = flux_long_Deacon(sHydro,varargin)
%R_long from atm is parameterized using Deacon (1970)

global sCryo sAtm

%VERSION WITH ONLY ONE FITTING PARAMETER
if isempty(varargin(:))
	argout = cell(0,6);
    argout = cat(1,argout, ['tsn',cell(1,5)]);
%     varargout(1,:) = {'longwave_scalar', 0, 100, 10, 'heat_long_Deacon'};
    return
else
%     scaleOut = find_att(varargin{1}.coef,'longwave_scalar'); 
end


% stefan = 5.67*10^(-8);

%First line is Swinbank's empricial formula for longwave input radiation
%(factor of 10 graeter than Eq. 1 in Deacon to convert units)
    %FOR CLEAR SKIES!
%Second line is elevation correction for incoming longwave (factor of 10 greater than Eq. 8 in Deacon to convert units)
%Third line is longwave radiation out from snow

argout = 5.31*10^(-13)*(squeeze(sAtm.tas(sAtm.indCurr,:,:)) + 273.15).^6 ...
    - 0.035*(sHydro.dem/1000).*5.67*10^(-8).*(squeeze(sAtm.tas(sAtm.indCurr,:,:)) + 273.15).^4 ...
    - 5.67*10^(-8)*(sCryo.tsn + 273.15).^4;



%VERSION WITH MUTLIPLE FITTING PARAMETERS:
% if isempty(varargin(:))
% 	argout = cell(2,5);
%     argout(1,:) = {'longwave_z_slope', 0.001, 0.1, 0.035, 'heat_long_Deacon'};
%     argout(2,:) = {'longwave_out_scalar', 0, 100, 10, 'heat_long_Deacon'};
%     return
% else
%     zSlope = find_att(varargin{1}.coef,'longwave_z_slope'); 
%     scaleOut = find_att(varargin{1}.coef,'longwave_out_scalar'); 
% end
% 
% 
% % stefan = 5.67*10^(-8);
% 
% %First line is Swinbank's empricial formula for longwave input radiation
% %(factor of 10 less than Eq. 1 in Deacon to convert units)
%     %FROM CLEAR SKIES!
% %Second line is elevation correction for incoming longwave (factor of 10 less than Eq. 8 in Deacon to convert units)
% %Third line is longwave radiation out from snow
% 
% 
% argout = scaleOut*5.31*10^(-15)*(squeeze(sAtm.tas(sAtm.indCurr,:,:)) + 273.15).^6 ...
%     - 5.67*10^(-9)*zSlope*(sHydro.dem/1000).*(squeeze(sAtm.tas(sAtm.indCurr,:,:)) + 273.15).^4 ...
%     - 5.67*10^(-8)*(sSnow.tmp + 273.15).^4;
