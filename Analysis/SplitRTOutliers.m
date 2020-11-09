%SplitRTOutliers.m
%Created 10/2/19 by A. Bosen
%
%This script takes a vector of reaction times and recursively removes outliers,
%defined as any RT above mean + 4 sd. Removal recurses until no data points meet
%this definition, at which point the non-outliers and outliers are returned as
%separate variables.

function [remainingRTs, outlierRTs] = SplitRTOutliers(RTdata)
	outlierCutoff = mean(RTdata) + 4 * std(RTdata);
	remainingRTs = RTdata;
	outlierRTs = [];
	while(any(remainingRTs > outlierCutoff))
		%Find any points that meet the current cutoff for outlier
		newOutlierIndex = remainingRTs > outlierCutoff;
		%Add those points to the outlier vector
		outlierRTs = [outlierRTs;remainingRTs(newOutlierIndex)];
		%Remove those points from the reminaing RT vector
		remainingRTs(newOutlierIndex) = [];
		%Define a new cutoff based on the remaining RTs
		outlierCutoff = mean(remainingRTs) + 4 * std(remainingRTs);
	end
end
