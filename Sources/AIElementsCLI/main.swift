import Foundation
import AIElementsCLIKit

let arguments = Array(CommandLine.arguments.dropFirst())
do {
    let output = try CLI().run(arguments)
    print(output, terminator: output.hasSuffix("\n") ? "" : "\n")
} catch {
    let output = CLI.errorOutput(error, json: arguments.contains("--json")) + "\n"
    FileHandle.standardError.write(Data(output.utf8))
    exit((error as? CLIError)?.exitCode ?? 1)
}
