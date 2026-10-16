// Read-only profiling of production MissionReader. Records counts and timings,
// never titles, screenshots, user file contents, or other-app mutations.
import Cocoa
import ApplicationServices
import Darwin

@main struct ReaderPerformance {
    static func cpuSeconds() -> Double {
        var usage=rusage();getrusage(RUSAGE_SELF,&usage)
        return Double(usage.ru_utime.tv_sec+usage.ru_stime.tv_sec)+Double(usage.ru_utime.tv_usec+usage.ru_stime.tv_usec)/1_000_000
    }
    static func main() {
        let mode=CommandLine.arguments.dropFirst().first ?? "idle"
        guard ["idle","active"].contains(mode),AXIsProcessTrusted() else { fputs("Use idle or active from an Accessibility-trusted environment.\n",stderr);exit(2) }
        let expectedActive=mode=="active",count=expectedActive ? 30 : 100,reader=MissionReader()
        let start=DispatchTime.now().uptimeNanoseconds,cpuStart=cpuSeconds()
        var times:[Double]=[],matched:[Int]=[],thumbnails:[Int]=[],stateMatches=0
        for _ in 0..<count {
            let before=DispatchTime.now().uptimeNanoseconds
            let snapshot=reader.read()
            times.append(Double(DispatchTime.now().uptimeNanoseconds-before)/1_000_000)
            matched.append(snapshot.thumbnails.filter { $0.window != nil }.count);thumbnails.append(snapshot.thumbnails.count)
            if snapshot.active==expectedActive { stateMatches+=1 }
            let spent=Double(DispatchTime.now().uptimeNanoseconds-before)/1_000_000_000
            if spent<0.18 { Thread.sleep(forTimeInterval:0.18-spent) }
        }
        let elapsed=Double(DispatchTime.now().uptimeNanoseconds-start)/1_000_000_000,cpu=cpuSeconds()-cpuStart
        var usage=rusage();getrusage(RUSAGE_SELF,&usage)
        let sorted=times.sorted()
        func percentile(_ p:Double)->Double { sorted[min(sorted.count-1,Int(ceil(Double(sorted.count)*p))-1)] }
        let report:[String:Any]=["recordedAt":ISO8601DateFormatter().string(from:Date()),"os":ProcessInfo.processInfo.operatingSystemVersionString,"mode":mode,"samples":count,"expectedStateSamples":stateMatches,"firstReadMS":times[0],"p50MS":percentile(0.5),"p95MS":percentile(0.95),"maxMS":times.max()!,"readsOver180MS":times.filter{$0>180}.count,"readsOver1000MS":times.filter{$0>=1000}.count,"wallSeconds":elapsed,"readerProcessCPUSeconds":cpu,"readerProcessCPUPercentOfOneCore":cpu/elapsed*100,"readerProcessPeakRSSBytes":usage.ru_maxrss,"minThumbnails":thumbnails.min()!,"maxThumbnails":thumbnails.max()!,"minMatched":matched.min()!,"maxMatched":matched.max()!,"scope":"Production MissionReader only, at nominal 180ms cadence. Inherits CLI Accessibility authorization. Excludes GUI, event tap, overlays, AX/WindowServer process CPU, other hardware/OS, and long-run leak assessment. Existing approved legacy GUI may be polling concurrently."]
        let data=try! JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
        try! data.write(to:URL(fileURLWithPath:"reports/reader-performance-\(mode).json"),options:.atomic)
        print("Recorded \(mode): \(stateMatches)/\(count) expected states, p95 \(percentile(0.95)) ms; report: reports/reader-performance-\(mode).json")
        if stateMatches != count { exit(3) }
    }
}
