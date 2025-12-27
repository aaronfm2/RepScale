import SwiftUI

// MARK: - Tutorial Data Structures

enum SpotlightArea {
    case topRight
    case topLeft
    case center
    case tab(index: Int)
    case none
}

struct TutorialStep {
    let id: Int
    let title: String
    let description: String
    let tabIndex: Int
    let highlights: [SpotlightArea] // Areas to highlight (e.g. [.topRight, .center])
}

// MARK: - Tutorial Overlay View

struct TutorialOverlayView: View {
    let step: TutorialStep
    let onNext: () -> Void
    let onFinish: () -> Void
    let isLastStep: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. Dark Background with "Holes"
                Color.black.opacity(0.7)
                    .mask(
                        ZStack {
                            Rectangle().fill(Color.white) // The solid part
                            
                            // Punch holes
                            ForEach(0..<step.highlights.count, id: \.self) { i in
                                spotlightShape(for: step.highlights[i], in: geometry)
                                    .blendMode(.destinationOut)
                            }
                        }
                    )
                    .ignoresSafeArea()
                    .allowsHitTesting(true) // Blocks touches to underlying app
                
                // 2. Text & Controls
                VStack {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text(step.title)
                            .font(.title2).bold()
                            .foregroundColor(.white)
                        
                        Text(step.description)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                        
                        HStack {
                            Spacer()
                            Button(action: isLastStep ? onFinish : onNext) {
                                Text(isLastStep ? "Finish" : "Next")
                                    .fontWeight(.bold)
                                    .padding(.vertical, 10)
                                    .padding(.horizontal, 24)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(UIColor.systemGray6).opacity(0.2))
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Lift up from bottom tab bar
                }
                
                // 3. Arrows / Indicators (Optional visual flair)
                ForEach(0..<step.highlights.count, id: \.self) { i in
                    arrowView(for: step.highlights[i], in: geometry)
                }
            }
        }
    }
    
    
    // MARK: - Geometry Helpers
        
        func spotlightShape(for area: SpotlightArea, in geo: GeometryProxy) -> some View {
            let spotlightSize: CGFloat = 55
            let topBarY = geo.safeAreaInsets.top + 22
            
            var frame = CGRect.zero
            
            switch area {
            case .topRight:
                let xPos = geo.size.width - 33
                frame = CGRect(x: xPos - (spotlightSize / 2), y: topBarY - (spotlightSize / 2), width: spotlightSize, height: spotlightSize)
                
            case .topLeft:
                let xPos: CGFloat = 30
                frame = CGRect(x: xPos - (spotlightSize / 2), y: topBarY - (spotlightSize / 2), width: spotlightSize, height: spotlightSize)
                
            case .center:
                frame = CGRect(x: 20, y: geo.size.height / 2 - 200, width: geo.size.width - 40, height: 400)
                
            case .tab(let index):
                // Calculate X based on tab count (4 tabs)
                let tabWidth = geo.size.width / 4
                let xCenter = (CGFloat(index) * tabWidth) + (tabWidth / 2)
                
                // Calculate Y: Tab bar is at bottom, above safe area
                // Standard tab bar height is ~49. Center is ~25pts above bottom safe area.
                let yCenter = geo.size.height - geo.safeAreaInsets.bottom - -62
                
                frame = CGRect(x: xCenter - (spotlightSize / 2 + 5),
                               y: yCenter - (spotlightSize / 2 + 5),
                               width: spotlightSize + 10,
                               height: spotlightSize + 10)
                
            case .none:
                break
            }
            
            return Circle()
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
        }
        
        @ViewBuilder
        func arrowView(for area: SpotlightArea, in geo: GeometryProxy) -> some View {
            let topArrowY = geo.safeAreaInsets.top + 50
            
            switch area {
            case .topRight:
                Image(systemName: "arrow.up.right")
                    .resizable().frame(width: 50, height: 50).foregroundColor(.white)
                    .position(x: geo.size.width - 90, y: topArrowY)
                    
            case .topLeft:
                Image(systemName: "arrow.up.left")
                    .resizable().frame(width: 50, height: 50).foregroundColor(.white)
                    .position(x: 90, y: topArrowY)
                    
            case .tab(let index):
                // Pointing DOWN at the tab
                let tabWidth = geo.size.width / 4
                let xCenter = (CGFloat(index) * tabWidth) + (tabWidth / 2)
                
                // Position arrow above the tab bar spotlight
                let yArrow = geo.size.height - geo.safeAreaInsets.bottom - 45
                
                Image(systemName: "arrow.down")
                    .resizable().frame(width: 35, height: 35).foregroundColor(.white)
                    .position(x: xCenter, y: yArrow)
                    
            default:
                EmptyView()
            }
        }
}
