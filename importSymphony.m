function experiment = importSymphony(project, filePath)
    import ch.systemsx.cisd.hdf5.*;
    
    reader = HDF5Factory.openForReading(filePath);
    
    experimentGroup = [];
    members = reader.getGroupMemberInformation('/', true);
    for i = 1:members.size()
        m = members.get(i-1);
        if m.isGroup()
            experimentGroup = m;
            break;
        end
    end
    if isempty(experimentGroup)
        error('No experiment (top-level) group found');
    end
    
    experiment = readExperiment(project, reader, char(experimentGroup.getPath())); 
end

function experiment = readExperiment(project, reader, experimentPath)

    purpose = reader.getStringAttribute(experimentPath, 'purpose');
    [startTime, endTime] = getTimes(reader, experimentPath);
    
    %experiment = project.insertExperiment(purpose, startTime, endTime);
    experiment = [];
    disp('experiment:');
    disp(purpose);
    disp(startTime);
    disp(endTime);
    
    % Read sources.
    sources = reader.getGroupMemberInformation([experimentPath '/sources'], true);
    for i = 1:sources.size()
        readSource(experiment, reader, char(sources.get(i-1).getPath()));
    end
    
    % Read epoch groups.
    groups = reader.getGroupMemberInformation([experimentPath '/epochGroups'], true);
    for i = 1:groups.size()
        readEpochGroup(experiment, reader, char(groups.get(i-1).getPath())); 
    end
end

function source = readSource(parent, reader, sourcePath)
    
    label = reader.getStringAttribute(sourcePath, 'label');
    
    %source = parent.insertSource(label);
    source = [];
    disp('source:');
    disp(label);
    
    children = reader.getGroupMemberInformation([sourcePath '/sources'], true);
    for i = 1:children.size()
        readSource(source, reader, char(children.get(i-1).getPath()));
    end
end

function epochGroup = readEpochGroup(parent, reader, groupPath)
    
    label = reader.getStringAttribute(groupPath, 'label');
    [startTime, endTime] = getTimes(reader, groupPath);
    
    %epochGroup = parent.insertEpochGroup(source, label, startTime, endTime);
    epochGroup = [];
    disp('epoch group:');
    disp(label);
    disp(startTime);
    disp(endTime);
end

function [s, e] = getTimes(reader, path)
    s = getStartTime(reader, path);
    if reader.hasAttribute(path, 'endTimeDotNetDateTimeOffsetTicks') ...
            && reader.hasAttribute(path, 'endTimeDotNetDateTimeOffsetOffsetHours')
        e = getEndTime(reader, path);
    else
        e = [];
    end
end

function t = getStartTime(reader, path)
    ticks = reader.getLongAttribute(path, 'startTimeDotNetDateTimeOffsetTicks');
    offset = reader.getDoubleAttribute(path, 'startTimeDotNetDateTimeOffsetOffsetHours');
    t = dotNetTicksToDateTime(ticks, offset);
end

function t = getEndTime(reader, path)
    ticks = reader.getLongAttribute(path, 'endTimeDotNetDateTimeOffsetTicks');
    offset = reader.getDoubleAttribute(path, 'endTimeDotNetDateTimeOffsetOffsetHours');
    t = dotNetTicksToDateTime(ticks, offset);
end

function t = dotNetTicksToDateTime(ticks, offset)
    import java.time.*;

    tz = ZoneOffset.ofHours(offset);
    dotNetRefDate = ZonedDateTime.of(1, 1, 1, 0, 0, 0, 0, tz);

    javaRefDate = Instant.EPOCH.atZone(ZoneId.of('UTC'));
    
    ms = ticks / 1e4;
    assert(ms < java.lang.Long.MAX_VALUE, 'Long integer overflow.');
    
    tmp = Instant.ofEpochMilli(ms);
    
    t = tmp.minus(Duration.between(dotNetRefDate, javaRefDate));
    t = t.atZone(tz);
end