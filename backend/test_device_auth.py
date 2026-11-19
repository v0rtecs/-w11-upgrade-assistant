import hashlib
import json
import os
import tempfile
import unittest
from device_auth import authorized, load_registry

class DeviceAuthTests(unittest.TestCase):
    def test_identity_binding_and_revocation(self):
        secret = "A" * 48
        other = "B" * 48
        registry = {"reception": hashlib.sha256(secret.encode()).hexdigest(),
                    "office": hashlib.sha256(other.encode()).hexdigest()}
        self.assertTrue(authorized(registry, "reception", "Bearer " + secret))
        self.assertFalse(authorized(registry, "office", "Bearer " + secret))
        self.assertFalse(authorized(registry, "reception", "Bearer wrong"))
        del registry["reception"]
        self.assertFalse(authorized(registry, "reception", "Bearer " + secret))

    def test_registry_validation(self):
        with tempfile.TemporaryDirectory() as directory:
            path = os.path.join(directory, "registry.json")
            with open(path, "w", encoding="utf-8") as file:
                json.dump({"pc-01": "a" * 64}, file)
            self.assertEqual(load_registry(path)["pc-01"], "a" * 64)
            with open(path, "w", encoding="utf-8") as file:
                json.dump({"../bad": "a" * 64}, file)
            with self.assertRaises(ValueError):
                load_registry(path)

if __name__ == "__main__":
    unittest.main()
