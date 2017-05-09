function experiment = importSymphony(project, filePath)
    % Add JHDF5 to the java path
    jhdfPath = which('sis-jhdf5.jar');
    if isempty(jhdfPath)
        error('Cannot find sis-jhdf5.jar on matlab path');
    end
    if ~any(strcmpi(javaclasspath, jhdfPath))
        javaaddpath(jhdfPath);
    end
    
    import ch.systemsx.cisd.hdf5.*;
    
    reader = HDF5Factory.openForReading(filePath);
    
    % Read experiment
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
    
    experiment = project.insertExperiment(purpose, startTime, endTime);
    fprintf('experiment: %s, %s, %s', purpose, startTime, endTime);
    
    addAnnotations(reader, experimentPath, experiment);
    
    % Read devices
    devices = reader.getGroupMemberInformation([experimentPath '/devices'], true);
    for i = 1:devices.size()
        readDevice(experiment, reader, char(devices.get(i-1).getPath()));
    end
    
    % Read sources
    sources = reader.getGroupMemberInformation([experimentPath '/sources'], true);
    for i = 1:sources.size()
        readSource(experiment, reader, char(sources.get(i-1).getPath()));
    end
    
    % Read epoch groups
    groups = reader.getGroupMemberInformation([experimentPath '/epochGroups'], true);
    for i = 1:groups.size()
        readEpochGroup(experiment, reader, char(groups.get(i-1).getPath())); 
    end
end

function device = readDevice(experiment, reader, devicePath)
    name = reader.getStringAttribute(devicePath, 'name');
    manufacturer = reader.getStringAttribute(devicePath, 'manufacturer');
    
    device = experiment.insertDevice(name, manufacturer);
    fprintf('device: %s, %s', name, manufacturer);
    
    addAnnotations(reader, devicePath, device);
end

function device = findDevice(experiment, name, manufacturer)
    device = experiment.getDevice(name, manufacturer);
end

function source = readSource(parent, reader, sourcePath)
    label = reader.getStringAttribute(sourcePath, 'label');
    ticks = reader.getLongAttribute(sourcePath, 'creationTimeDotNetDateTimeOffsetTicks');
    offset = reader.getDoubleAttribute(sourcePath, 'creationTimeDotNetDateTimeOffsetOffsetHours');
    creationTime = dotNetTicksToDatetime(ticks, offset);
    id = reader.getStringAttribute(sourcePath, 'uuid');
    
    source = parent.insertSource(label, creationTime, id);
    fprintf('source: %s, %s, %s', label, creationTime, id);
    
    addAnnotations(reader, sourcePath, source);
    
    % Read nested sources
    children = reader.getGroupMemberInformation([sourcePath '/sources'], true);
    for i = 1:children.size()
        readSource(source, reader, char(children.get(i-1).getPath()));
    end
end

function source = findSource(experiment, id)
    sources = experiment.getAllSourcesWithIdentifier(id);
    if ~isempty(sources)
        source = sources{1};
    end
    if numel(sources) > 1
        warning(['Found multiple sources with identifier ' char(uuid)]);
    end
end

function group = readEpochGroup(parent, reader, groupPath)
    if parent.getEntityType() == encore.core.EntityType.EXPERIMENT
        experiment = parent;
    else
        experiment = parent.experiment;
    end

    sourceId = reader.getStringAttribute([groupPath '/source'], 'uuid');
    source = findSource(experiment, sourceId);

    label = reader.getStringAttribute(groupPath, 'label');
    [startTime, endTime] = readTimes(reader, groupPath);
    
    group = parent.insertEpochGroup(source, label, startTime, endTime);
    fprintf('epoch group: %s, %s, %s, %s', sourceId, label, startTime, endTime);
    
    addAnnotations(reader, groupPath, group);
    
    % Read epoch blocks
    blocks = reader.getGroupMemberInformation([groupPath '/epochBlocks'], true);
    for i = 1:blocks.size()
        readEpochBlock(group, reader, char(blocks.get(i-1).getPath()));
    end
    
    % Read nested epoch groups
    children = reader.getGroupMemberInformation([groupPath '/epochGroups'], true);
    for i = 1:children.size()
        readEpochGroup(group, reader, char(children.get(i-1).getPath()));
    end
end

function block = readEpochBlock(epochGroup, reader, blockPath)
    protocolId = reader.getStringAttribute(blockPath, 'protocolID');
    protocolParameters = readDictionary(reader, blockPath, 'protocolParameters');
    [startTime, endTime] = readTimes(reader, blockPath);

    block = epochGroup.insertEpochBlock(protocolId, protocolParameters, startTime, endTime);
    fprintf('epoch block: %s, [%s], %s, %s', protocolId, appbox.mapstr(protocolParameters), startTime, endTime);
    
    addAnnotations(reader, blockPath, block);
    
    % Read epochs
    epochs = reader.getGroupMemberInformation([blockPath '/epochs'], true);
    for i = 1:epochs.size()
        readEpoch(block, reader, char(epochs.get(i-1).getPath()));
    end
end

function epoch = readEpoch(epochBlock, reader, epochPath)
    protocolParameters = readDictionary(reader, epochPath, 'protocolParameters');
    [startTime, endTime] = readTimes(reader, epochPath);

    epoch = epochBlock.insertEpoch(protocolParameters, startTime, endTime);
    fprintf('epoch: %s, %s, [%s]', startTime, endTime, appbox.mapstr(protocolParameters));
    
    addAnnotations(reader, epochPath, epoch);
    
    % Read backgrounds
    backgrounds = reader.getGroupMemberInformation([epochPath '/backgrounds'], true);
    for i = 1:backgrounds.size()
        readBackground(epoch, reader, char(backgrounds.get(i-1).getPath()));
    end
    
    % Read stimuli
    stimuli = reader.getGroupMemberInformation([epochPath '/stimuli'], true);
    for i = 1:stimuli.size()
        readStimulus(epoch, reader, char(stimuli.get(i-1).getPath()));
    end
    
    % Read responses
    responses = reader.getGroupMemberInformation([epochPath '/responses'], true);
    for i = 1:responses.size()
        readResponse(epoch, reader, char(responses.get(i-1).getPath()));
    end
end

function background = readBackground(epoch, reader, backgroundPath)
    deviceName = reader.getStringAttribute([backgroundPath '/device'], 'name');
    deviceManufacturer = reader.getStringAttribute([backgroundPath '/device'], 'manufacturer');
    device = findDevice(epoch.epochBlock.epochGroup.experiment, deviceName, deviceManufacturer);
    deviceParameters = readDeviceParameters(reader, backgroundPath, device.name);
    
    value = reader.getFloatAttribute(backgroundPath, 'value');
    valueUnits = reader.getStringAttribute(backgroundPath, 'valueUnits');
    sampleRate = reader.getFloatAttribute(backgroundPath, 'sampleRate');
    sampleRateUnits = reader.getStringAttribute(backgroundPath, 'sampleRateUnits');

    background = epoch.insertBackground(device, deviceParameters, value, valueUnits, sampleRate, sampleRateUnits);
    fprintf('background: %s, [%s], %s, %s, %s, %s', deviceName, appbox.mapstr(deviceParameters), num2str(value), valueUnits, num2str(sampleRate), sampleRateUnits);
    
    addAnnotations(reader, backgroundPath, background);
end

function stimulus = readStimulus(epoch, reader, stimulusPath)
    deviceName = reader.getStringAttribute([stimulusPath '/device'], 'name');
    deviceManufacturer = reader.getStringAttribute([stimulusPath '/device'], 'manufacturer');
    device = findDevice(epoch.epochBlock.epochGroup.experiment, deviceName, deviceManufacturer);
    deviceParameters = readDeviceParameters(reader, stimulusPath, device.name);
    
    stimulusId = reader.getStringAttribute(stimulusPath, 'stimulusID');
    parameters = readDictionary(reader, stimulusPath, 'parameters');
    units = reader.getStringAttribute(stimulusPath, 'units');
    
    if hasGroupMember(reader, stimulusPath, 'data')
        [data, units] = readMeasurements(reader, stimulusPath, 'data');
    else
        data = [];
    end

    stimulus = epoch.insertStimulus(device, deviceParameters, stimulusId, parameters, units, data);
    fprintf('stimulus: %s, [%s], %s, [%s], %s, [%s]', deviceName, appbox.mapstr(deviceParameters), stimulusId, appbox.mapstr(parameters), units, num2str(size(data)));
    
    addAnnotations(reader, stimulusPath, stimulus);
end

function response = readResponse(epoch, reader, responsePath)
    deviceName = reader.getStringAttribute([responsePath '/device'], 'name');
    deviceManufacturer = reader.getStringAttribute([responsePath '/device'], 'manufacturer');
    device = findDevice(epoch.epochBlock.epochGroup.experiment, deviceName, deviceManufacturer);
    deviceParameters = readDeviceParameters(reader, responsePath, device.name);
    
    [data, units] = readMeasurements(reader, responsePath, 'data');
    sampleRate = reader.getFloatAttribute(responsePath, 'sampleRate');
    sampleRateUnits = reader.getStringAttribute(responsePath, 'sampleRateUnits');

    response = epoch.insertResponse(device, deviceParameters, data, units, sampleRate, sampleRateUnits);
    fprintf('response: %s, [%s], [%s], %s, %s, %s', deviceName, appbox.mapstr(deviceParameters), num2str(size(data)), units, num2str(sampleRate), sampleRateUnits);
    
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
    entity.addProperty('__symphony__uuid__', uuid);
    
    fprintf(', %s\n', uuid);
end

function tf = hasProperties(reader, entityPath)
    tf = hasGroupMember(reader, entityPath, 'properties');
end

function addProperties(reader, entityPath, entity)
    properties = readDictionary(reader, entityPath, 'properties');
    keys = properties.keys;
    for i = 1:numel(keys)
        key = keys{i};
        entity.addProperty(key, properties(key));
    end

    fprintf(', properties[%s]', appbox.mapstr(properties));
end

function tf = hasNotes(reader, entityPath)
    tf = hasGroupMember(reader, entityPath, 'notes');
end

function addNotes(reader, entityPath, entity)
    [notes, times] = readNotes(reader, entityPath, 'notes');
    for i = 1:numel(notes)
        entity.addNote(times(i), notes{i});
    end
    fprintf(', notes{%s}', strjoin(notes, ', '));
end

function [n, t] = readNotes(reader, path, dsetName)
    file = H5F.open(char(reader.getFile()), 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
    dset = H5D.open(file, [path '/' dsetName]);
    
    datatype = H5T.open(file, 'NOTE');
    rnotes = H5D.read(dset, datatype, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT');
    
    H5T.close(datatype);
    H5D.close(dset);
    H5F.close(file);
    
    n = rnotes.text';
    t = [];
    for i = 1:numel(rnotes.time.ticks)
        time = dotNetTicksToDatetime(rnotes.time.ticks(i), rnotes.time.offsetHours(i));
        if isempty(t)
            t = time;
        else
            t(end + 1) = time; %#ok<AGROW>
        end
    end
end

function tf = hasResources(reader, entityPath)
    tf = hasGroupMember(reader, entityPath, 'resources');
end

function addResources(reader, entityPath, entity)
    fprintf(', {\n');
    resources = reader.getGroupMemberInformation([entityPath '/resources'], true);
    for i = 1:resources.size()
        readResource(entity, reader, char(resources.get(i-1).getPath()));
    end
    fprintf('}');
end

function resource = readResource(entity, reader, resourcePath)
    uti = reader.getStringAttribute(resourcePath, 'uti');
    name = reader.getStringAttribute(resourcePath, 'name');
    data = typecast(reader.readAsByteArray([resourcePath '/data']), 'uint8');
    
    resource = entity.addResource(name, data, uti);
    fprintf('\tresource: %s, [%s], %s', name, num2str(size(data)), uti);
    
    addAnnotations(reader, resourcePath, resource);
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
    keywordsStr = char(reader.getStringAttribute(entityPath, 'keywords'));
    keywords = strsplit(keywordsStr, ',');
    for i = 1:numel(keywords)
        entity.addKeyword(keywords(i));
    end
    fprintf(', keywords{%s}', strjoin(keywords, ', '));
end

function [q, u] = readMeasurements(reader, path, dsetName)
    file = H5F.open(char(reader.getFile()), 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
    dset = H5D.open(file, [path '/' dsetName]);
    
    datatype = H5T.open(file, 'MEASUREMENT');
    rdata = H5D.read(dset, datatype, 'H5S_ALL', 'H5S_ALL', 'H5P_DEFAULT');
    
    H5T.close(datatype);
    H5D.close(dset);
    H5F.close(file);
    
    q = rdata.quantity';    
    u = cellstr(unique(rdata.units', 'rows'));
    if numel(u) > 1
        error('Units are not homogenous in measurement data');
    end
    u = u{1};
end

function p = readDeviceParameters(reader, path, deviceName)
    spansGroup = [path '/dataConfigurationSpans'];
    nSpans = reader.getGroupMembers(spansGroup).size();
    
    p = containers.Map();
    for i = 1:nSpans
        span = [spansGroup '/span_' num2str(i-1)];
        
        nodes = reader.getGroupMembers(span);
        for j = 1:nodes.size()
            node = char(nodes.get(j-1));
            if strcmp(node, deviceName)
                params = readDictionary(reader, span, char(nodes.get(j-1)));
                keys = params.keys;
                for k = 1:numel(keys)
                    key = keys{k};
                    value = params(key);

                    if p.isKey(key)
                        p(key) = [p(key), {value}];
                    else
                        p(key) = value;
                    end
                end
                break;
            end
        end
    end
end

function d = readDictionary(reader, group, name)
    import ch.systemsx.cisd.hdf5.*;

    d = containers.Map();
    
    dictGroup = [group '/' name];
    attributeNames = reader.getAttributeNames(dictGroup);
    for i = 1:attributeNames.size()
        attr = char(attributeNames.get(i-1));
        info = reader.getAttributeInformation(dictGroup, attr);
        
        if info.getDataClass() == HDF5DataClass.STRING
            d(attr) = char(reader.getStringAttribute(dictGroup, attr));            
        elseif info.getDataClass() == HDF5DataClass.INTEGER
            if info.getElementSize() == 4
                if info.getNumberOfElements() > 1
                    d(attr) = int32(reader.getIntArrayAttribute(dictGroup, attr));
                else
                    d(attr) = int32(reader.getIntAttribute(dictGroup, attr));
                end
            elseif info.getElementSize() == 8
                if info.getNumberOfElements() > 1
                    d(attr) = int64(reader.getLongArrayAttribute(dictGroup, attr));
                else
                    d(attr) = int64(reader.getLongAttribute(dictGroup, attr));
                end
            elseif info.getElementSize() == 2
                if info.getNumberOfElements() > 1
                    d(attr) = int16(reader.getShortArrayAttribute(dictGroup, attr));
                else
                    d(attr) = int16(reader.getShortAttribute(dictGroup, attr));
                end
            else
                error([dictGroup '.' attr ' is not a supported attribute type']);
            end
        elseif info.getDataClass() == HDF5DataClass.FLOAT
            if info.getElementSize() == 4
                if info.getNumberOfElements() > 1
                    d(attr) = single(reader.getFloatArrayAttribute(dictGroup, attr));
                else
                    d(attr) = single(reader.getFloatAttribute(dictGroup, attr));
                end
            elseif info.getElementSize() == 8
                if info.getNumberOfElements() > 1
                    d(attr) = double(reader.getDoubleArrayAttribute(dictGroup, attr));
                else
                    d(attr) = double(reader.getDoubleAttribute(dictGroup, attr));
                end
            else
                error([dictGroup '.' attr ' is not a supported attribute type']);
            end
        elseif info.getDataClass() == HDF5DataClass.BOOLEAN
            d(attr) = reader.getBooleanAttribute(dictGroup, attr);
        else
            error([dictGroup '.' attr ' is not a supported attribute type']);
        end
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
    t = dotNetTicksToDatetime(ticks, offset);
end

function tf = hasEndTime(reader, path)
    tf = reader.hasAttribute(path, 'endTimeDotNetDateTimeOffsetTicks') ...
        && reader.hasAttribute(path, 'endTimeDotNetDateTimeOffsetOffsetHours');
end

function t = readEndTime(reader, path)
    ticks = reader.getLongAttribute(path, 'endTimeDotNetDateTimeOffsetTicks');
    offset = reader.getDoubleAttribute(path, 'endTimeDotNetDateTimeOffsetOffsetHours');
    t = dotNetTicksToDatetime(ticks, offset);
end

function t = dotNetTicksToDatetime(ticks, offset)
    import java.time.*;

    tz = ZoneOffset.ofHours(offset);
    dotNetRefDate = ZonedDateTime.of(1, 1, 1, 0, 0, 0, 0, tz);

    javaRefDate = Instant.EPOCH.atZone(ZoneId.of('UTC'));
    
    ms = ticks / 1e4;
    assert(ms < java.lang.Long.MAX_VALUE, 'Long integer overflow.');
    
    tmp = Instant.ofEpochMilli(ms);
    
    zdt = tmp.minus(Duration.between(dotNetRefDate, javaRefDate));
    zdt = zdt.atZone(tz);
    
    second = double(zdt.getSecond()) + (double(zdt.getNano()) / 10^9);
    t = datetime(zdt.getYear(), zdt.getMonthValue(), zdt.getDayOfMonth(), zdt.getHour(), zdt.getMinute(), second);
    tz = char(zdt.getZone().toString());
    t.TimeZone = tz;
end