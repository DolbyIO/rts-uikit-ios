//
//  StatsInfoButton.swift
//

import DolbyIORTSCore
import DolbyIOUIKit
import SwiftUI

struct StatsInfoButton: View {

    private let viewModel: StatsInfoViewModel
    @State private var showStats: Bool = false

    init(streamSource: StreamSource) {
        viewModel = StatsInfoViewModel(streamSource: streamSource)
    }

    var body: some View {
        IconButton(
            iconAsset: .info
        ) {
            showStats.toggle()
        }
        .contentShape(Rectangle())
        .sheet(isPresented: $showStats) {
            StatisticsView(streamSource: viewModel.streamSource)
        }
    }
}

struct StatisticsView: View {
    private let viewModel: StatisticsViewModel

    @ObservedObject private var themeManager = ThemeManager.shared

    init(streamSource: StreamSource) {
        viewModel = StatisticsViewModel(streamSource: streamSource)
    }

    var body: some View {
        ScrollView {
            VStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray)
                    .frame(width: 48, height: 5)
                    .padding([.top], 5)
                Text("stream.media-stats.label",
                     font: .custom("AvenirNext-DemiBold", size: FontSize.title2, relativeTo: .title))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding([.top], 20)
                    .padding([.bottom], 25)

                HStack {
                    Text("stream.stats.name.label",
                         font: .custom("AvenirNext-DemiBold", size: FontSize.title2, relativeTo: .title))
                    .frame(width: 170, alignment: .leading)
                    Text("stream.stats.value.label",
                         font: .custom("AvenirNext-DemiBold", size: FontSize.title2, relativeTo: .title))
                    .frame(width: 170, alignment: .leading)
                }
                .padding([.leading, .trailing], 15)

                ForEach(viewModel.data) { item in
                    HStack {
                        Text(item.key,
                             font: .custom("AvenirNext-Regular", size: FontSize.body, relativeTo: .body))
                            .frame(width: 170, alignment: .leading)
                        
                        Text(verbatim: item.value,
                             font: .custom("AvenirNext-DemiBold", size: FontSize.caption1, relativeTo: .caption))
                            .frame(width: 170, alignment: .leading)
                    }
                    .padding([.top], 5)
                    .padding([.leading, .trailing], 15)
                }
            }.padding([.bottom], 10)
        }.frame(maxWidth: 500, maxHeight: 600, alignment: .bottom)
            .background {
                Rectangle().fill(Color(uiColor: themeManager.theme.background).opacity(0.7))
                    .ignoresSafeArea(.container, edges: .all)
            }
            .cornerRadius(Layout.cornerRadius14x)
    }
}


final class StatisticsViewModel {
    private let streamSource: StreamSource

    init(streamSource: StreamSource) {
        self.streamSource = streamSource
    }

    struct StatData: Identifiable {
        var id = UUID()
        var key: LocalizedStringKey
        var value: String
    }

    var data: [StatData] {
        guard let stats = streamSource.streamingStats else {
            return []
        }

        var result = [StatData]()

        if let val = stats.statsInboundRtp?.decoderImplementation {
            result.append(StatData(key: "stream.stats.decoder-impl.label", value: String(val)))
        }
        if let val = stats.statsInboundRtp?.processingDelay {
            result.append(StatData(key: "stream.stats.processing-delay.label", value: String(format:"%.2f ms", val)))
        }
        if let val = stats.statsInboundRtp?.decodeTime {
            result.append(StatData(key: "stream.stats.decode-time.label", value: String(format:"%.2f ms", val)))
        }
        if let videoResolution = stats.statsInboundRtp?.videoResolution {
            result.append(StatData(key: "stream.stats.video-resolution.label", value: videoResolution))
        }
        if let fps = stats.statsInboundRtp?.fps {
            result.append(StatData(key: "stream.stats.fps.label", value: String(fps)))
        }
        if let videoBytesReceived = stats.statsInboundRtp?.bytesReceived {
            result.append(StatData(key: "stream.stats.video-total-received.label", value: formatBytes(bytes: videoBytesReceived)))
        }
        if let val = stats.statsInboundRtp?.packetsReceived {
            result.append(StatData(key: "stream.stats.packets-received.label", value: String(format:"%.2f", val)))
        }
        if let val = stats.statsInboundRtp?.framesDecoded {
            result.append(StatData(key: "stream.stats.frames-decoded.label", value: String(val)))
        }
        if let val = stats.statsInboundRtp?.framesDropped {
            result.append(StatData(key: "stream.stats.frames-dropped.label", value: String(val)))
        }
        if let val = stats.statsInboundRtp?.jitterBufferEmittedCount {
            result.append(StatData(key: "stream.stats.jitter-buffer-est-count.label", value: String(val)))
        }
        if let videoJitter = stats.statsInboundRtp?.jitter {
            result.append(StatData(key: "stream.stats.video-jitter.label", value: "\(videoJitter) ms"))
        }
        if let val = stats.statsInboundRtp?.jitterBufferDelay {
            result.append(StatData(key: "stream.stats.jitter-buffer-delay.label", value: String(format:"%.2f ms", val)))
        }
        if let val = stats.statsInboundRtp?.jitterBufferTargetDelay {
            result.append(StatData(key: "stream.stats.jitter-buffer-target-delay.label", value: String(format:"%.2f ms", val)))
        }
        if let val = stats.statsInboundRtp?.jitterBufferMinimumtDelay {
            result.append(StatData(key: "stream.stats.jitter-buffer-minimum-delay.label", value: String(format:"%.2f ms", val)))
        }
        if let videoPacketsLost = stats.statsInboundRtp?.packetsLost {
            result.append(StatData(key: "stream.stats.video-packet-loss.label", value: String(format:"%.2f", videoPacketsLost)))
        }

        
        if let rtt = stats.roundTripTime {
            result.append(StatData(key: "stream.stats.rtt.label", value: String(rtt)))
        }

//        if let audioPacketsLost = stats.audioStatsInboundRtp?.packetsLost {
//            result.append(StatData(key: "stream.stats.audio-packet-loss.label", value: String(audioPacketsLost)))
//        }
//        if let audioJitter = stats.audioStatsInboundRtp?.jitter {
//            result.append(StatData(key: "stream.stats.audio-jitter.label", value: "\(audioJitter)"))
//        }
        if let timestamp = stats.statsInboundRtp?.timestamp {
            result.append(StatData(key: "stream.stats.timestamp.label", value: String(timestamp))) // change to dateStr when timestamp is fixed
        }
        let audioCodec = stats.statsInboundRtp?.codecName
        let videoCodec = stats.statsInboundRtp?.codecName
        if audioCodec != nil || videoCodec != nil {
            var delimiter = ", "
            if audioCodec == nil || videoCodec == nil {
                delimiter = ""
            }
            let codecs = "\(audioCodec ?? "")\(delimiter)\(videoCodec ?? "")"
            result.append(StatData(key: "stream.stats.codecs.label", value: codecs))
        }
        return result
    }

    private func dateStr(timestamp: Double) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT")
        dateFormatter.locale = NSLocale.current
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        return dateFormatter.string(from: date)
    }

    private func formatBytes(bytes: Int) -> String {
        return "\(formatNumber(input: bytes))B"
    }

    private func formatBitRate(bitRate: Int) -> String {
        let value = formatNumber(input: bitRate).lowercased()
        return "\(value)bps"
    }

    private func formatNumber(input: Int) -> String {
        if input < KILOBYTES { return String(input) }
        if input >= KILOBYTES && input < MEGABYTES { return "\(input / KILOBYTES) K"} else { return "\(input / MEGABYTES) M" }
    }
}

private let KILOBYTES = 1024
private let MEGABYTES = KILOBYTES * KILOBYTES
