# Tink (pulled in by androidx.security:security-crypto) references
# compile-time-only annotations that are not on the runtime classpath.
# Without these rules R8 fails release builds with "Missing class" errors.
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**
-dontwarn javax.annotation.concurrent.**
