function tests = importSymphonyTest()
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    rootPath = fullfile(fileparts(mfilename('fullpath')), '..');
    testCase.applyFixture(matlab.unittest.fixtures.PathFixture(rootPath));    
    testCase.TestData.fixtureDir = fullfile(rootPath, 'fixtures');
end

function testImport(testCase)
    fixturePath = fullfile(testCase.TestData.fixtureDir, '2017-02-27.h5');
    
    experiment = importSymphony([], fixturePath);
    
    testCase.verifyFail('not yet implemented');
end