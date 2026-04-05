//
//  ReportGenerator.swift
//  Akusti-Scan-App-RT60
//
//  PDF report generation for acoustic analysis
//

import PDFKit
import UIKit
import SwiftUI

/// Report generator for acoustic analysis results
@MainActor
final class ReportGenerator {

    // MARK: - PDF Generation

    /// Generate PDF report from acoustic analysis
    func generatePDF(analysis: AcousticAnalysis, room: Room? = nil) -> Data? {
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)  // A4

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()

            var yPosition: CGFloat = 50

            // Title
            yPosition = drawTitle(in: context.cgContext, pageRect: pageRect, y: yPosition)

            // Header info
            yPosition = drawHeader(analysis: analysis, in: context.cgContext, pageRect: pageRect, y: yPosition)

            // Room info
            if let room = room {
                yPosition = drawRoomInfo(room: room, in: context.cgContext, pageRect: pageRect, y: yPosition)
            }

            // RT60 Results Table
            yPosition = drawRT60Table(analysis: analysis, in: context.cgContext, pageRect: pageRect, y: yPosition)

            // Check if we need a new page
            if yPosition > pageRect.height - 200 {
                context.beginPage()
                yPosition = 50
            }

            // Quality Assessment
            yPosition = drawQualityAssessment(analysis: analysis, in: context.cgContext, pageRect: pageRect, y: yPosition)

            // RT60 Chart
            yPosition = drawRT60Chart(analysis: analysis, in: context.cgContext, pageRect: pageRect, y: yPosition)

            // Footer
            drawFooter(in: context.cgContext, pageRect: pageRect)
        }

        return data
    }

    /// Generate and share PDF
    func sharePDF(analysis: AcousticAnalysis, room: Room? = nil) -> URL? {
        guard let pdfData = generatePDF(analysis: analysis, room: room) else {
            return nil
        }

        let fileName = "RT60_Report_\(dateFormatter.string(from: analysis.timestamp)).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try pdfData.write(to: tempURL)
            return tempURL
        } catch {
            print("Failed to write PDF: \(error)")
            return nil
        }
    }

    // MARK: - Drawing Helpers

    private func drawTitle(in context: CGContext, pageRect: CGRect, y: CGFloat) -> CGFloat {
        let title = "Akustik-Analyse Bericht"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]

        let titleSize = title.size(withAttributes: titleAttributes)
        let titleRect = CGRect(
            x: (pageRect.width - titleSize.width) / 2,
            y: y,
            width: titleSize.width,
            height: titleSize.height
        )
        title.draw(in: titleRect, withAttributes: titleAttributes)

        return y + titleSize.height + 20
    }

    private func drawHeader(analysis: AcousticAnalysis, in context: CGContext, pageRect: CGRect, y: CGFloat) -> CGFloat {
        let margin: CGFloat = 50
        var currentY = y

        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray
        ]

        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]

        // Date
        let dateLabel = "Datum: "
        let dateValue = dateFormatter.string(from: analysis.timestamp)
        drawLabelValue(label: dateLabel, value: dateValue, labelAttrs: labelAttributes, valueAttrs: headerAttributes, x: margin, y: currentY)
        currentY += 20

        // Room name
        let roomLabel = "Raum: "
        drawLabelValue(label: roomLabel, value: analysis.roomName, labelAttrs: labelAttributes, valueAttrs: headerAttributes, x: margin, y: currentY)
        currentY += 20

        // Volume
        let volumeLabel = "Volumen: "
        let volumeValue = String(format: "%.1f m³", analysis.roomVolume)
        drawLabelValue(label: volumeLabel, value: volumeValue, labelAttrs: labelAttributes, valueAttrs: headerAttributes, x: margin, y: currentY)

        // Surface area (same line, right side)
        let areaLabel = "Oberfläche: "
        let areaValue = String(format: "%.1f m²", analysis.roomSurfaceArea)
        drawLabelValue(label: areaLabel, value: areaValue, labelAttrs: labelAttributes, valueAttrs: headerAttributes, x: 300, y: currentY)

        return currentY + 40
    }

    private func drawRoomInfo(room: Room, in context: CGContext, pageRect: CGRect, y: CGFloat) -> CGFloat {
        let margin: CGFloat = 50
        var currentY = y

        let sectionTitle = "Raumabmessungen"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        sectionTitle.draw(at: CGPoint(x: margin, y: currentY), withAttributes: titleAttributes)
        currentY += 25

        let infoAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray
        ]

        let dimensions = String(format: "Länge: %.2f m  |  Breite: %.2f m  |  Höhe: %.2f m", room.length, room.width, room.height)
        dimensions.draw(at: CGPoint(x: margin, y: currentY), withAttributes: infoAttributes)
        currentY += 18

        let conditions = String(format: "Temperatur: %.1f °C  |  Luftfeuchtigkeit: %.0f %%", room.temperature, room.humidity)
        conditions.draw(at: CGPoint(x: margin, y: currentY), withAttributes: infoAttributes)

        return currentY + 30
    }

    private func drawRT60Table(analysis: AcousticAnalysis, in context: CGContext, pageRect: CGRect, y: CGFloat) -> CGFloat {
        let margin: CGFloat = 50
        var currentY = y

        // Section title
        let sectionTitle = "Nachhallzeit RT60 nach Frequenzband"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        sectionTitle.draw(at: CGPoint(x: margin, y: currentY), withAttributes: titleAttributes)
        currentY += 25

        // Table header
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.white
        ]

        let cellAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]

        let columns: [String] = ["Frequenz", "Gemessen", "Sabine", "Eyring", "T20", "T30"]
        let columnWidth: CGFloat = (pageRect.width - 2 * margin) / CGFloat(columns.count)
        let rowHeight: CGFloat = 22

        // Draw header background
        context.setFillColor(UIColor.systemBlue.cgColor)
        context.fill(CGRect(x: margin, y: currentY, width: pageRect.width - 2 * margin, height: rowHeight))

        // Draw header text
        for (index, column) in columns.enumerated() {
            let x = margin + CGFloat(index) * columnWidth + 5
            column.draw(at: CGPoint(x: x, y: currentY + 5), withAttributes: headerAttributes)
        }
        currentY += rowHeight

        // Draw data rows
        for (index, band) in FrequencyBand.allCases.enumerated() {
            // Alternate row background
            if index % 2 == 0 {
                context.setFillColor(UIColor.systemGray6.cgColor)
                context.fill(CGRect(x: margin, y: currentY, width: pageRect.width - 2 * margin, height: rowHeight))
            }

            let row: [String] = [
                band.rawValue,
                formatRT60(analysis.measuredRT60?[band]),
                formatRT60(analysis.sabineRT60[band]),
                formatRT60(analysis.eyringRT60[band]),
                formatRT60(analysis.t20?[band]),
                formatRT60(analysis.t30?[band])
            ]

            for (colIndex, value) in row.enumerated() {
                let x = margin + CGFloat(colIndex) * columnWidth + 5
                value.draw(at: CGPoint(x: x, y: currentY + 5), withAttributes: cellAttributes)
            }

            currentY += rowHeight
        }

        // Draw table border
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.stroke(CGRect(x: margin, y: y + 25, width: pageRect.width - 2 * margin, height: currentY - y - 25))

        return currentY + 20
    }

    private func drawQualityAssessment(analysis: AcousticAnalysis, in context: CGContext, pageRect: CGRect, y: CGFloat) -> CGFloat {
        let margin: CGFloat = 50
        var currentY = y

        // Section title
        let sectionTitle = "Bewertung"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        sectionTitle.draw(at: CGPoint(x: margin, y: currentY), withAttributes: titleAttributes)
        currentY += 25

        // Average RT60
        let avgRT60 = analysis.averageMeasuredRT60 ?? analysis.averageSabineRT60
        let avgLabel = String(format: "Durchschnittliche Nachhallzeit: %.2f s", avgRT60)
        let avgAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.systemBlue
        ]
        avgLabel.draw(at: CGPoint(x: margin, y: currentY), withAttributes: avgAttributes)
        currentY += 25

        // Quality assessment
        let assessmentAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.darkGray
        ]
        analysis.qualityAssessment.draw(at: CGPoint(x: margin, y: currentY), withAttributes: assessmentAttributes)

        return currentY + 40
    }

    private func drawRT60Chart(analysis: AcousticAnalysis, in context: CGContext, pageRect: CGRect, y: CGFloat) -> CGFloat {
        let margin: CGFloat = 50
        let chartWidth = pageRect.width - 2 * margin
        let chartHeight: CGFloat = 150
        var currentY = y

        // Section title
        let sectionTitle = "RT60 Frequenzgang"
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        sectionTitle.draw(at: CGPoint(x: margin, y: currentY), withAttributes: titleAttributes)
        currentY += 25

        // Chart background
        context.setFillColor(UIColor.systemGray6.cgColor)
        context.fill(CGRect(x: margin, y: currentY, width: chartWidth, height: chartHeight))

        // Find max RT60 for scaling
        let allValues = Array(analysis.sabineRT60.values) + (analysis.measuredRT60.map { Array($0.values) } ?? [])
        let maxRT60 = max(allValues.max() ?? 2.0, 1.0)

        let barWidth = chartWidth / CGFloat(FrequencyBand.allCases.count) - 10
        let bands = FrequencyBand.allCases

        // Draw bars
        for (index, band) in bands.enumerated() {
            let x = margin + CGFloat(index) * (barWidth + 10) + 5

            // Sabine bar
            let sabineValue = analysis.sabineRT60[band] ?? 0
            let sabineHeight = CGFloat(sabineValue / maxRT60) * (chartHeight - 30)
            context.setFillColor(UIColor.systemBlue.withAlphaComponent(0.6).cgColor)
            context.fill(CGRect(x: x, y: currentY + chartHeight - sabineHeight - 20, width: barWidth / 2, height: sabineHeight))

            // Measured bar (if available)
            if let measured = analysis.measuredRT60?[band] {
                let measuredHeight = CGFloat(measured / maxRT60) * (chartHeight - 30)
                context.setFillColor(UIColor.systemGreen.cgColor)
                context.fill(CGRect(x: x + barWidth / 2, y: currentY + chartHeight - measuredHeight - 20, width: barWidth / 2, height: measuredHeight))
            }

            // Frequency label
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 8),
                .foregroundColor: UIColor.darkGray
            ]
            let label = band.rawValue.replacingOccurrences(of: " Hz", with: "").replacingOccurrences(of: " kHz", with: "k")
            label.draw(at: CGPoint(x: x, y: currentY + chartHeight - 15), withAttributes: labelAttributes)
        }

        // Legend
        currentY += chartHeight + 10
        let legendAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.darkGray
        ]

        context.setFillColor(UIColor.systemBlue.withAlphaComponent(0.6).cgColor)
        context.fill(CGRect(x: margin, y: currentY, width: 12, height: 12))
        "Sabine (berechnet)".draw(at: CGPoint(x: margin + 15, y: currentY), withAttributes: legendAttributes)

        context.setFillColor(UIColor.systemGreen.cgColor)
        context.fill(CGRect(x: margin + 150, y: currentY, width: 12, height: 12))
        "Gemessen".draw(at: CGPoint(x: margin + 165, y: currentY), withAttributes: legendAttributes)

        return currentY + 30
    }

    private func drawFooter(in context: CGContext, pageRect: CGRect) {
        let footer = "Erstellt mit Akusti-Scan RT60 • \(dateFormatter.string(from: Date()))"
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.lightGray
        ]

        let footerSize = footer.size(withAttributes: footerAttributes)
        let footerRect = CGRect(
            x: (pageRect.width - footerSize.width) / 2,
            y: pageRect.height - 30,
            width: footerSize.width,
            height: footerSize.height
        )
        footer.draw(in: footerRect, withAttributes: footerAttributes)
    }

    // MARK: - Helper Functions

    private func drawLabelValue(label: String, value: String, labelAttrs: [NSAttributedString.Key: Any], valueAttrs: [NSAttributedString.Key: Any], x: CGFloat, y: CGFloat) {
        label.draw(at: CGPoint(x: x, y: y), withAttributes: labelAttrs)
        let labelWidth = label.size(withAttributes: labelAttrs).width
        value.draw(at: CGPoint(x: x + labelWidth, y: y), withAttributes: valueAttrs)
    }

    private func formatRT60(_ value: Double?) -> String {
        guard let value = value else { return "-" }
        return String(format: "%.2f s", value)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }
}
