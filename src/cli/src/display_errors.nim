## CLI wrapper around Yumly's optional error renderer.

import ../../yumly/errors/renderer
import ../../yumly/types/errors
import ./display

proc printDiagnostic*(errorValue: ref YumlyError, fallbackPath = "",
    fallbackContent = "") =
  error(formatError(errorValue, fallbackPath, fallbackContent))

proc printDiagnostic*(errorValue: ref YumlyIOError, fallbackPath = "",
    fallbackContent = "") =
  error(formatError(errorValue, fallbackPath, fallbackContent))
