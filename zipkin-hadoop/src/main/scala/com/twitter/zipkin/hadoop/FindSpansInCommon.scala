package com.twitter.zipkin.hadoop

import com.twitter.scalding._
import com.twitter.zipkin.hadoop.sources.FixedSpanSource
import java.sql.Timestamp
import java.text.SimpleDateFormat
import cascading.pipe.joiner.LeftJoin

class FindSpansInCommon(args : Args) extends Job(args) {

  val file = Tsv(args.required("file"))
  val logs = Tsv(args.required("logs"))

  val infoFromFile = file
    .read
    .mapTo((0, 1) -> ('id, 'timestamp)) { data: (Long, Long) => data }

  val infoFromLogs = logs
    .read
    .mapTo((0, 1) -> ('id, 'timestamp)) { data: (Long, Long) => data }

  val result = infoFromFile
    .groupBy('id, 'timestamp) {  _.sum('id, 'timestamp) }
    //.joinWithSmaller('id -> 'idFromFile, infoFromLogs, joiner = new LeftJoin())
    //.map('id, 'idFromFile)
    //.filter('service_logs){ s : String => s == null }
    .write(Tsv(args("output")))
}