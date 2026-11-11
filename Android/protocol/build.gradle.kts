plugins { kotlin("jvm"); kotlin("plugin.serialization"); `java-library` }
kotlin { jvmToolchain(17) }
dependencies {
    api("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.1")
    testImplementation(kotlin("test-junit"))
}
sourceSets {
    main { resources.srcDir("../../Sources/AIElementsUIProtocol/Resources") }
}
