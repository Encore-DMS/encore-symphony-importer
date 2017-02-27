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
    [startTime, endTime] = readTimes(reader, experimentPath);
    
    %experiment = project.insertExperiment(purpose, startTime, endTime);
    experiment = [];
    fprintf('experiment: %s, %s, %s', purpose, startTime, endTime);
    
    addAnnotations(reader, experimentPath, experiment);
    
    % Read devices.
    devices = reader.getGroupMemberInformation([experimentPath '/devices'], true);
    for i = 1:devices.size()
        readDevice(experiment, reader, char(devices.get(i-1).getPath()));
    end
    
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

function device = readDevice(experiment, reader, devicePath)
    
    name = reader.getStringAttribute(devicePath, 'name');
    manufacturer = reader.getStringAttribute(devicePath, 'manufacturer');

    %device = experimnet.insertDevice(name, manufacturer);
    device = [];
    fprintf('device: %s, %s', name, manufacturer);
    
    addAnnotations(reader, devicePath, device);
end

function device = findDevice(context, uuid)
    device = [];
end

function source = readSource(parent, reader, sourcePath)
    
    label = reader.getStringAttribute(sourcePath, 'label');
    
    %source = parent.insertSource(label);
    source = [];
    fprintf('source: %s', label);
    
    addAnnotations(reader, sourcePath, source);
    
    % Read nested sources.
    children = reader.getGroupMemberInformation([sourcePath '/sources'], true);
    for i = 1:children.size()
        readSource(source, reader, char(children.get(i-1).getPath()));
    end
end

function source = findSource(context, uuid)
    source = [];
end

function group = readEpochGroup(parent, reader, groupPath)
    
    sourceUuid = reader.getStringAttribute([groupPath '/source'], 'uuid');
    %source = findSource(parent.getDataContext(), sourceUuid);
    source = [];

    label = reader.getStringAttribute(groupPath, 'label');
    [startTime, endTime] = readTimes(reader, groupPath);
    
    %group = parent.insertEpochGroup(source, label, startTime, endTime);
    group = [];
    fprintf('epoch group: %s, %s, %s, %s', sourceUuid, label, startTime, endTime);
    
    addAnnotations(reader, groupPath, group);
    
    % Read epoch blocks.
    blocks = reader.getGroupMemberInformation([groupPath '/epochBlocks'], true);
    for i = 1:blocks.size()
        readEpochBlock(group, reader, char(blocks.get(i-1).getPath()));
    end
    
    % Read nested epoch groups.
    children = reader.getGroupMemberInformation([groupPath '/epochGroups'], true);
    for i = 1:children.size()
        readEpochGroup(group, reader, char(children.get(i-1).getPath()));
    end
end

function block = readEpochBlock(epochGroup, reader, blockPath)
    
    protocolId = reader.getStringAttribute(blockPath, 'protocolID');
    parameters = [];
    [startTime, endTime] = readTimes(reader, blockPath);

    %block = epochGroup.insertEpochBlock(protocolId, parameters, startTime, endTime);
    block = [];
    fprintf('epoch block: %s, %s, %s, %s', protocolId, parameters, startTime, endTime);
    
    addAnnotations(reader, blockPath, block);
    
    % Read epochs.
    epochs = reader.getGroupMemberInformation([blockPath '/epochs'], true);
    for i = 1:epochs.size()
        readEpoch(block, reader, char(epochs.get(i-1).getPath()));
    end
end

function epoch = readEpoch(epochBlock, reader, epochPath)

    [startTime, endTime] = readTimes(reader, epochPath);

    %epoch = epochBlock.insertEpoch(startTime, endTime);
    epoch = [];
    fprintf('epoch: %s, %s', startTime, endTime);
    
    addAnnotations(reader, epochPath, epoch);
    
    stimuli = reader.getGroupMemberInformation([epochPath '/stimuli'], true);
    for i = 1:stimuli.size()
        readStimulus(epoch, reader, char(stimuli.get(i-1).getPath()));
    end
    
    responses = reader.getGroupMemberInformation([epochPath '/responses'], true);
    for i = 1:responses.size()
        readResponse(epoch, reader, char(responses.get(i-1).getPath()));
    end
end

function stimulus = readStimulus(epoch, reader, stimulusPath)

    deviceUuid = reader.getStringAttribute([stimulusPath '/device'], 'uuid');
    %device = findDevice(epoch.getDataContext(), deviceUuid);
    device = [];
    
    stimulusId = reader.getStringAttribute(stimulusPath, 'stimulusID');
    units = reader.getStringAttribute(stimulusPath, 'units');

    %stimulus = epoch.insertStimulus(device, deviceParameters, stimulusId, parameters, units);
    stimulus = [];
    fprintf('stimulus: %s, %s, %s', deviceUuid, stimulusId, units);
    
    addAnnotations(reader, stimulusPath, stimulus);
end

function response = readResponse(epoch, reader, responsePath)

    deviceUuid = reader.getStringAttribute([responsePath '/device'], 'uuid');
    %device = findDevice(epoch.getDataContext(), deviceUuid);
    device = [];

    sampleRate = reader.getFloatAttribute(responsePath, 'sampleRate');
    sampleRateUnits = reader.getStringAttribute(responsePath, 'sampleRateUnits');

    %response = epoch.insertResponse(device, deviceParameters, data, units, sampleRate, sampleRateUnits);
    response = [];
    fprintf('response: %s, %s, %s', deviceUuid, num2str(sampleRate), sampleRateUnits);
    
    addAnnotations(reader, responsePath, response);
end

function addAnnotations(reader, entityPath, entity)
    if hasProperties(reader, entityPath)
        addProperties(reader, entityPath, entity);
    end
    if hasNotes(reader, entityPath)
        addNotes(reader, entityPath, entity);
    end
    if hasResources(reader, entityPath)
        addResources(reader, entityPath, entity);
    end
    if hasKeywords(reader, entityPath)
        addKeywords(reader, entityPath, entity);
    end
    uuid = reader.getStringAttribute(entityPath, 'uuid');
    %entity.addProperty('__symphony__uuid__', uuid);
    
    fprintf(', %s\n', uuid);
end

function tf = hasProperties(reader, entityPath)
    tf = hasGroupMember(reader, entityPath, 'properties');
end

function addProperties(reader, entityPath, entity)
    fprintf(', properties');
end

function tf = hasNotes(reader, entityPath)
    tf = hasGroupMember(reader, entityPath, 'notes');
end

function addNotes(reader, entityPath, entity)
    fprintf(', notes');
end

function tf = hasResources(reader, entityPath)
    tf = hasGroupMember(reader, entityPath, 'resources');
end

function addResources(reader, entityPath, entity)
    fprintf(', resources');
end

function tf = hasGroupMember(reader, path, name)
    tf = false;
    names = reader.getGroupMembers(path);
    for i = 1:names.size()
        if strcmp(char(names.get(i-1)), name)
            tf = true;
            break;
        end
    end
end

function tf = hasKeywords(reader, entityPath)
    tf = false;
    names = reader.getAttributeNames(entityPath);
    for i = 1:names.size()
        if strcmp(char(names.get(i-1)), 'keywords')
            tf = true;
            break;
        end
    end
end

function addKeywords(reader, entityPath, entity)
    keywordsStr = reader.getStringAttribute(entityPath, 'keywords');
    keywords = keywordsStr.split(',');
    for i = 1:numel(keywords)
        %entity.addTag(keywords(i));
    end
end

function [s, e] = readTimes(reader, path)
    s = readStartTime(reader, path);
    if hasEndTime(reader, path)
        e = readEndTime(reader, path);
    else
        e = [];
    end
end

function t = readStartTime(reader, path)
    ticks = reader.getLongAttribute(path, 'startTimeDotNetDateTimeOffsetTicks');
    offset = reader.getDoubleAttribute(path, 'startTimeDotNetDateTimeOffsetOffsetHours');
    t = dotNetTicksToDateTime(ticks, offset);
end

function tf = hasEndTime(reader, path)
    tf = reader.hasAttribute(path, 'endTimeDotNetDateTimeOffsetTicks') ...
        && reader.hasAttribute(path, 'endTimeDotNetDateTimeOffsetOffsetHours');
end

function t = readEndTime(reader, path)
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