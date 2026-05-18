name := "spark-jobs"
version := "0.1.0"
scalaVersion := "2.12.18"

val sparkVersion = "3.5.3"

// Spark deps: provided at runtime, available in test scope
val sparkDeps = Seq(
  "org.apache.spark" %% "spark-core" % sparkVersion,
  "org.apache.spark" %% "spark-sql"  % sparkVersion,
  "org.apache.spark" %% "spark-hive" % sparkVersion,
)

libraryDependencies ++= sparkDeps.map(_ % "provided")
libraryDependencies ++= sparkDeps.map(_ % "test")

libraryDependencies ++= Seq(
  "com.typesafe"  %  "config"    % "1.4.3",
  "org.scalatest" %% "scalatest" % "3.2.19" % "test",
)

// Assembly
assembly / assemblyJarName := s"spark-jobs-assembly-${version.value}.jar"

assembly / assemblyMergeStrategy := {
  case PathList("META-INF", "services", _*) => MergeStrategy.concat
  case PathList("META-INF", _*)             => MergeStrategy.discard
  case "reference.conf"                     => MergeStrategy.concat
  case _                                    => MergeStrategy.first
}

// Do not bundle provided Spark/Hadoop JARs into the fat JAR
assembly / assemblyExcludedJars := {
  (assembly / fullClasspath).value.filter { f =>
    val n = f.data.getName
    n.startsWith("spark-") || n.startsWith("hadoop-") || n == "scala-library.jar"
  }
}

// Faster test runs
Test / parallelExecution := false
Test / fork := false
