import ProjectDescription

let name = "MarkdownRendererExample"

let app = Target.target(
    name: name,
    destinations: [.iPhone, .iPad],
    product: .app,
    bundleId: "com.murad.\(name)",
    deploymentTargets: .iOS("16.0"),
    infoPlist: nil,
    buildableFolders: [.folder("Example")],
    dependencies: [.package(product: "MarkdownRenderer", type: .runtime)],
    settings: .settings(base: [
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "GENERATE_INFOPLIST_FILE": "YES",
        "MARKETING_VERSION": "1.0",
        "CURRENT_PROJECT_VERSION": "1",
        "INFOPLIST_KEY_CFBundleDisplayName": "Markdown Renderer",
        "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
        "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
        "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations": "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight",
    ])
)

let project = Project(
    name: name,
    options: .options(
        automaticSchemesOptions: .disabled,
        disableBundleAccessors: true,
        disableSynthesizedResourceAccessors: true
    ),
    settings: .settings(base: [
        "SWIFT_VERSION": "6.0",
        "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
    ]),
    targets: [app],
    schemes: [
        .scheme(
            name: name,
            buildAction: .buildAction(targets: [.target(name)]),
            runAction: .runAction(executable: .target(name))
        ),
    ]
)
