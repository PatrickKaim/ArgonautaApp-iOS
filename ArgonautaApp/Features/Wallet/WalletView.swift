import SwiftUI

struct WalletView: View {
    @State private var viewModel = WalletViewModel()
    @State private var showQRFullScreen = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    balanceCard
                    qrCodeSection
                    transactionsList
                }
                .padding()
            }
            .background(ArgoTheme.groupedBackground)
            .navigationTitle("Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await viewModel.loadData() }
            .onAppear { Task { await viewModel.loadData() } }
            .fullScreenCover(isPresented: $showQRFullScreen) {
                QRFullScreenView(cardCode: viewModel.cardCode ?? "")
            }
        }
    }

    private var balanceCard: some View {
        VStack(spacing: 8) {
            Text("Saldo").font(.argoCaption).foregroundStyle(.white.opacity(0.8))
            Text("\(viewModel.balance)").font(.argoLargeNumber).foregroundStyle(.white)
            Text("Argo's").font(.argoSubheadline).foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            LinearGradient(colors: [ArgoTheme.blueNormal, ArgoTheme.blueDark], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var qrCodeSection: some View {
        Group {
            if let cardCode = viewModel.cardCode {
                VStack(spacing: 8) {
                    QRCodeView(code: cardCode, size: 180)
                        .onTapGesture { showQRFullScreen = true }
                    Text("Tik voor volledig scherm").font(.argoCaption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var transactionsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recente transacties").font(.argoHeadline)
            if viewModel.recentTransactions.isEmpty {
                Text("Geen transacties").font(.argoBody).foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.recentTransactions) { tx in
                    TransactionRow(transaction: tx)
                }
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: WalletViewModel.Transaction

    var body: some View {
        HStack {
            Image(systemName: transaction.amount >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundStyle(transaction.amount >= 0 ? .green : .red)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.desc).font(.argoBody).lineLimit(1)
                Text(transaction.date.shortDateString).font(.argoCaption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(transaction.amount >= 0 ? "+\(transaction.amount)" : "\(transaction.amount)")
                .font(.argoSubheadline)
                .foregroundStyle(transaction.amount >= 0 ? .green : .red)
        }
        .padding(.vertical, 4)
    }
}
