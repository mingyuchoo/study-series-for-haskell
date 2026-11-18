import unittest

from metadata import (
    compiler_target,
    linux_libraries,
    package_version,
    windows_libraries,
)


class MetadataTests(unittest.TestCase):
    def test_requires_one_consistent_numeric_package_version(self):
        self.assertEqual(
            package_version(["version: 0.1.0.0", "version: 0.1.0.0"]), "0.1.0.0"
        )
        for sources in (
            [],
            ["name: cli"],
            ["version: 1.0", "version: 2.0"],
            ["version: 1.0\nversion: 2.0"],
            ["version: 1.0;exit"],
        ):
            with self.subTest(sources=sources), self.assertRaises(ValueError):
                package_version(sources)

    def test_rejects_cross_compilers_and_unsupported_architectures(self):
        self.assertEqual(
            compiler_target("aarch64-unknown-linux", "Linux", "aarch64"),
            ("linux", "arm64"),
        )
        self.assertEqual(
            compiler_target("x86_64-w64-mingw32", "Windows", "AMD64"),
            ("windows", "x64"),
        )
        self.assertEqual(
            compiler_target("aarch64-apple-darwin", "Darwin", "arm64"),
            ("macos", "arm64"),
        )
        for triple, system, machine in (
            ("x86_64-unknown-linux", "Linux", "aarch64"),
            ("aarch64-apple-darwin", "Linux", "aarch64"),
            ("i386-unknown-linux", "Linux", "i386"),
        ):
            with self.subTest(triple=triple), self.assertRaises(ValueError):
                compiler_target(triple, system, machine)

    def test_collects_non_glibc_dependencies_and_rejects_unresolved_libraries(self):
        listing = """linux-vdso.so.1 (0x0000)
libgmp.so.10 => /lib/aarch64-linux-gnu/libgmp.so.10 (0x0000)
libc.so.6 => /lib/aarch64-linux-gnu/libc.so.6 (0x0000)
libm.so.6 => /lib/aarch64-linux-gnu/libm.so.6 (0x0000)
/lib/ld-linux-aarch64.so.1 (0x0000)
libffi.so.8 => /opt/custom libs/libffi.so.8 (0x0000)
"""
        self.assertEqual(
            linux_libraries(listing),
            {
                "libgmp.so.10": "/lib/aarch64-linux-gnu/libgmp.so.10",
                "libffi.so.8": "/opt/custom libs/libffi.so.8",
            },
        )
        with self.assertRaisesRegex(ValueError, "libmissing"):
            linux_libraries("libmissing.so.1 => not found")

    def test_reads_windows_import_tables_without_confusing_other_pe_fields(self):
        self.assertEqual(
            windows_libraries(
                "DLL Name: KERNEL32.dll\n  DLL Name: libgmp-10.dll\nName: unrelated"
            ),
            ["KERNEL32.dll", "libgmp-10.dll"],
        )


if __name__ == "__main__":
    unittest.main()
