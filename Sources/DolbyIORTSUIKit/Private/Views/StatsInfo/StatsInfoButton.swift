//
//  StatsInfoButton.swift
//

import DolbyIORTSCore
import DolbyIOUIKit
import SwiftUI

struct StatsInfoButton: View {
    
    private let viewModel: StatsInfoViewModel
    @Binding private var isShowingStatsScreen: Bool
    
    init(streamSource: StreamSource, showingStatsScreen: Binding<Bool>) {
        viewModel = StatsInfoViewModel(streamSource: streamSource)
        _isShowingStatsScreen = showingStatsScreen
    }
    
    var body: some View {
        IconButton(
            iconAsset: .info
        ) {
            isShowingStatsScreen.toggle()
        }
    }
}

struct StatisticsView: View {
    private let viewModel: StatisticsViewModel
    
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.presentationMode) var presentationMode

    init(streamSource: StreamSource) {
        viewModel = StatisticsViewModel(streamSource: streamSource)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ScrollView {
                    VStack {
                        HStack {
                            Text("stream.stats.name.label",
                                 font: .custom("AvenirNext-DemiBold", size: FontSize.title2, relativeTo: .title))
                            .frame(width: 170, alignment: .leading)
                            Text("stream.stats.value.label",
                                 font: .custom("AvenirNext-DemiBold", size: FontSize.title2, relativeTo: .title))
                            .frame(width: 170, alignment: .leading)
                        }
                        
                        ForEach(viewModel.data) { item in
                            HStack {
                                Text(item.key,
                                     font: .custom("AvenirNext-Regular", size: FontSize.body, relativeTo: .body))
                                .multilineTextAlignment(.leading)
                                .frame(width: 170, alignment: .leading)
                                
                                Text(verbatim: item.value,
                                     font: .custom("AvenirNext-DemiBold", size: FontSize.caption1, relativeTo: .caption))
                                .multilineTextAlignment(.leading)
                                .frame(width: 170, alignment: .leading)
                            }
                            .padding([.top], 5)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding([.top, .bottom], 30)
                    .background {
                        Color(uiColor: themeManager.theme.background).opacity(0.7)
                    }
                }
                .navigationBarHidden(false)
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("stream.media-stats.label")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        IconButton(iconAsset: .close) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                .contextMenu {
                    Button(action: {
                        copyToPasteboard(text: formattedText())
                    }) {
                        Text("Copy")
                        Image(systemName: "doc.on.doc")
                    }
                }
            }
        }
    }
    
    func formattedText() -> String {
        var text = ""
        viewModel.data.forEach  { item in
            text += "\(item.key.toString()): \(item.value)\n"
        }
        return text
    }
    
    func copyToPasteboard(text: String) {
        UIPasteboard.general.string = text
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
        
        if let val = stats.mid {
            result.append(StatData(key: "stream.stats.mid.label", value: String(val)))
        }
        
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
