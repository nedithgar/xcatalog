import Foundation
import XCStringsTestSupport

enum TestFixtures {
    static let empty = """
    {
      "sourceLanguage": "en",
      "strings": {},
      "version": "1.0"
    }
    """

    static let singleKeySingleLang = """
    {
      "sourceLanguage": "en",
      "strings": {
        "Hello": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "Hello"
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    static let singleKeyMultipleLangs = """
    {
      "sourceLanguage": "en",
      "strings": {
        "Hello": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "Hello"
              }
            },
            "ja": {
              "stringUnit": {
                "state": "translated",
                "value": "こんにちは"
              }
            },
            "de": {
              "stringUnit": {
                "state": "translated",
                "value": "Hallo"
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    static let multipleKeysPartialTranslations = """
    {
      "sourceLanguage": "en",
      "strings": {
        "Hello": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "Hello"
              }
            },
            "ja": {
              "stringUnit": {
                "state": "translated",
                "value": "こんにちは"
              }
            }
          }
        },
        "Goodbye": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "Goodbye"
              }
            }
          }
        },
        "Welcome": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "Welcome"
              }
            },
            "ja": {
              "stringUnit": {
                "state": "translated",
                "value": "ようこそ"
              }
            },
            "de": {
              "stringUnit": {
                "state": "translated",
                "value": "Willkommen"
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    static let japaneseSource = """
    {
      "sourceLanguage": "ja",
      "strings": {
        "こんにちは": {
          "localizations": {
            "ja": {
              "stringUnit": {
                "state": "translated",
                "value": "こんにちは"
              }
            },
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "Hello"
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    static let manyKeys = """
    {
      "sourceLanguage": "en",
      "strings": {
        "Key1": { "localizations": { "en": { "stringUnit": { "state": "translated", "value": "Value1" } } } },
        "Key2": { "localizations": { "en": { "stringUnit": { "state": "translated", "value": "Value2" } } } },
        "Key3": { "localizations": { "en": { "stringUnit": { "state": "translated", "value": "Value3" } } } },
        "Key4": { "localizations": { "en": { "stringUnit": { "state": "translated", "value": "Value4" } } } },
        "Key5": { "localizations": { "en": { "stringUnit": { "state": "translated", "value": "Value5" } } } },
        "Key6": { "localizations": { "en": { "stringUnit": { "state": "translated", "value": "Value6" } }, "ja": { "stringUnit": { "state": "translated", "value": "値6" } } } },
        "Key7": { "localizations": { "en": { "stringUnit": { "state": "translated", "value": "Value7" } }, "ja": { "stringUnit": { "state": "translated", "value": "値7" } } } },
        "Key8": { "localizations": { "en": { "stringUnit": { "state": "translated", "value": "Value8" } }, "ja": { "stringUnit": { "state": "translated", "value": "値8" } } } },
        "Key9": { "localizations": { "en": { "stringUnit": { "state": "translated", "value": "Value9" } } } },
        "Key10": { "localizations": { "en": { "stringUnit": { "state": "translated", "value": "Value10" } } } }
      },
      "version": "1.0"
    }
    """

    static let withStaleKeys = """
    {
      "sourceLanguage": "en",
      "strings": {
        "ActiveKey": {
          "localizations": {
            "en": { "stringUnit": { "state": "translated", "value": "Active" } }
          }
        },
        "StaleKey1": {
          "extractionState": "stale",
          "localizations": {
            "en": { "stringUnit": { "state": "translated", "value": "Stale 1" } }
          }
        },
        "StaleKey2": {
          "extractionState": "stale",
          "localizations": {
            "en": { "stringUnit": { "state": "translated", "value": "Stale 2" } },
            "ja": { "stringUnit": { "state": "translated", "value": "古い2" } }
          }
        },
        "ManualKey": {
          "extractionState": "manual",
          "localizations": {
            "en": { "stringUnit": { "state": "translated", "value": "Manual" } }
          }
        }
      },
      "version": "1.0"
    }
    """

    static let withNonTranslatableKey = """
    {
      "sourceLanguage": "en",
      "strings": {
        "BrandName": {
          "comment": "Proper noun shown as-is in every locale",
          "isCommentAutoGenerated": true,
          "shouldTranslate": false
        },
        "Hello": {
          "comment": "Greeting",
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "Hello"
              }
            },
            "ja": {
              "stringUnit": {
                "state": "translated",
                "value": "こんにちは"
              }
            }
          }
        }
      },
      "version": "1.0"
    }
    """

    static let realWorldSample = """
    {
      "sourceLanguage": "en",
      "strings": {
        "Hello, world!": {
          "comment": "A greeting displayed in the main view.",
          "isCommentAutoGenerated": true,
          "shouldTranslate": false
        },
        "SwiftUI makes small UI changes fast.": {
          "localizations": {
            "en": {
              "stringUnit": {
                "state": "translated",
                "value": "SwiftUI makes small UI changes fast."
              }
            },
            "ja": {
              "stringUnit": {
                "state": "translated",
                "value": "Japanese placeholder translation"
              }
            }
          }
        },
        "This view now has a bit more to say.": {
          "comment": "A description of the additional content in the `ContentView`.",
          "isCommentAutoGenerated": true,
          "localizations": {
            "fr": {
              "stringUnit": {
                "state": "translated",
                "value": "French placeholder translation"
              }
            },
            "ja": {
              "stringUnit": {
                "state": "needs_review",
                "value": "This view now has a bit more to say."
              }
            }
          }
        },
        "You can replace these lines with app content later.": {
          "comment": "A description of the content of the app.",
          "isCommentAutoGenerated": true,
          "shouldTranslate": false
        }
      },
      "version": "1.2"
    }
    """

    static let preflightMixedCatalog = SharedTestFixtures.preflightMixedCatalog
}

enum TestHelper {
    static func createTempFile(content: String) throws -> String {
        let tempDir = FileManager.default.temporaryDirectory
        let path = tempDir.appendingPathComponent("test_\(UUID().uuidString).xcstrings").path
        try content.write(toFile: path, atomically: true, encoding: .utf8)
        return path
    }

    static func removeTempFile(at path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
}
