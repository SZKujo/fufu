import AppKit
import SwiftUI

struct PetAssetPreviewPanel: View {
    let pet: PetRecord?
    @Binding var isExpanded: Bool
    @State private var isZoomPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("素材预览")
                        .font(.title3.weight(.semibold))
                    Text("原始图片")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    isExpanded = false
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .buttonStyle(.borderless)
                .help("收起素材预览")
            }

            if let pet, let asset = asset(for: pet) {
                Button {
                    isZoomPresented = true
                } label: {
                    Image(nsImage: asset.image)
                        .interpolation(.none)
                        .antialiased(false)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 210)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .help("点击放大查看")
                .sheet(isPresented: $isZoomPresented) {
                    PetAssetZoomView(petName: pet.name, asset: asset)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(asset.fileName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text("\(Int(asset.image.size.width)) × \(Int(asset.image.size.height)) px")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if pet.assetKind == .spriteSheet {
                        Text("9 行协议：待机、右拖、左拖、唤醒、悬停、出错、完成、思考、回复。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                ContentUnavailableView("没有可预览素材", systemImage: "photo", description: Text("选择一只宠物后查看原始素材。"))
            }

            Spacer()
        }
        .padding(16)
        .frame(minWidth: 220)
    }

    private func asset(for pet: PetRecord) -> PetAssetPreview? {
        guard
            let url = try? PetAssetManager.assetURL(for: pet.assetFileName),
            let image = NSImage(contentsOf: url)
        else {
            return nil
        }
        return PetAssetPreview(fileName: pet.assetFileName, url: url, image: image)
    }
}

private struct PetAssetZoomView: View {
    let petName: String
    let asset: PetAssetPreview
    @Environment(\.dismiss) private var dismiss
    @State private var zoom = 1.0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(petName) 素材")
                        .font(.headline)
                    Text(asset.fileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Slider(value: $zoom, in: 0.25...3)
                    .frame(width: 160)

                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(14)

            Divider()

            ScrollView([.horizontal, .vertical]) {
                Image(nsImage: asset.image)
                    .interpolation(.none)
                    .antialiased(false)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: max(240, asset.image.size.width * zoom),
                        height: max(240, asset.image.size.height * zoom)
                    )
                    .padding(20)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 760, minHeight: 560)
    }
}

private struct PetAssetPreview {
    var fileName: String
    var url: URL
    var image: NSImage
}
