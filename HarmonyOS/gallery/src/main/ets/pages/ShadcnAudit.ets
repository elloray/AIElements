import { ShadcnAuditCanvas } from './ShadcnAuditCanvas';

@Entry
@Component
struct ShadcnAudit {
  build() {
    WithTheme({ colorMode: ThemeColorMode.LIGHT }) { ShadcnAuditCanvas() }
  }
}
