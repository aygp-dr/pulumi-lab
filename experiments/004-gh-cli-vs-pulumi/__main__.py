# Minimal wrapper for Pulumi - loads Hy code
import hy; hy.importer._import_from_path("__main__.hy", "__main__", ".")