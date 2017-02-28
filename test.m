function test()
    rootPath = fileparts(mfilename('fullpath'));
    results = runtests(fullfile(rootPath, 'test', 'importSymphonyTest.m'));
    failed = sum([results.Failed]);
    if failed > 0
        error([num2str(failed) ' test(s) failed!']);
    end
end

