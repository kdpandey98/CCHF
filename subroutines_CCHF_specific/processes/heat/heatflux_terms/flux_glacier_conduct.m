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

function varargout = flux_glacier_conduct(varargin)

global sCryo

if isempty(varargin(:))
	varargout{1} = cell(0,6);
    varargout{1} = cat(1, varargout{1}, {'glacier_temp', -25, 0, -15, 'heat_conduction_const','cryo'});  
    varargout{1} = cat(1, varargout{1}, {'glacier_iso_depth', 0, 30, 10, 'heat_conduction_const','cryo'});  
    varargout{1} = cat(1, varargout{1}, ['tsn',cell(1,5)]);
    return
else
    tGlac = find_att(varargin{1}.coef,'glacier_temp');
    z = find_att(varargin{1}.coef,'glacier_iso_depth');
end

k = find_att(varargin{1}.global,'thermal_conduct_ice');

sCryo.hficc = zeros(size(sCryo.snw));


indIce = find(sCryo.icx > 0); 
sCryo.hficc(indIce) = -k *(sCryo.tsn(indIce) - tGlac)/z;
