function tests = importSymphonyTest()
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    rootPath = fullfile(fileparts(mfilename('fullpath')), '..');
    testCase.applyFixture(matlab.unittest.fixtures.PathFixture(rootPath));    
    testCase.TestData.fixtureDir = fullfile(rootPath, 'fixtures');
end

function setup(testCase)
    coordinator = encore.core.Encore.connect('', '', '');
    testCase.TestData.context = coordinator.getContext();
end

function testImport(testCase)
    project = testCase.TestData.context.insertProject('test', 'testing', datetime('now', 'TimeZone', 'local'));
    fixturePath = fullfile(testCase.TestData.fixtureDir, '2017-02-27.h5');
    
    experiment = importSymphony(project, fixturePath);
    
    testCase.verifyFail('not yet implemented');
end