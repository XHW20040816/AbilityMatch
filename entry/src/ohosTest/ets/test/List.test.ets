import abilityMatchUiTest from './AbilityMatchUi.test';
import certSearchPerfTest from './CertSearchPerf.test';

export default function testsuite() {
  certSearchPerfTest();
  abilityMatchUiTest();
}
