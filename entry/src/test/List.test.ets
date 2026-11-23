import honorQueryTest from './ets/HonorQuery.test';
import jobFilterTest from './ets/JobFilter.test';
import matchEngineTest from './ets/MatchEngine.test';
import resumeParseServiceTest from './ets/ResumeParseService.test';
import semanticMatchTest from './ets/SemanticMatch.test';

export default function testsuite(): void {
  resumeParseServiceTest();
  matchEngineTest();
  jobFilterTest();
  honorQueryTest();
  semanticMatchTest();
}
