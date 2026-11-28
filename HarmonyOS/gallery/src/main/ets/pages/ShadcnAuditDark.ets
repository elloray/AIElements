import { ShadcnAuditCanvas } from './ShadcnAuditCanvas';

@Entry
@Component
struct ShadcnAuditDark {
  build() {
    WithTheme({ colorMode: ThemeColorMode.DARK }) { ShadcnAuditCanvas() }
  }
}
