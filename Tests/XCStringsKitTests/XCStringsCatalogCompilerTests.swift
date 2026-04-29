import Testing
@testable import XCStringsKit

@Suite("xcstringstool process runner")
struct XCStringsCatalogCompilerTests {
    @Test("process runner drains large stdout and stderr before waiting")
    func processRunnerDrainsLargeOutputBeforeWaiting() {
        let script = """
        i=0
        while [ "$i" -lt 12000 ]; do
          printf 'stdout diagnostic line %05d abcdefghijklmnopqrstuvwxyz\\n' "$i"
          printf 'stderr diagnostic line %05d abcdefghijklmnopqrstuvwxyz\\n' "$i" 1>&2
          i=$((i + 1))
        done
        """

        let result = XCStringsCatalogCompiler.run(["/bin/sh", "-c", script])

        #expect(result.exitCode == 0)
        #expect(result.output.utf8.count > 1_000_000)
        #expect(result.output.contains("stdout diagnostic line 00000"))
        #expect(result.output.contains("stderr diagnostic line 11999"))
    }
}
