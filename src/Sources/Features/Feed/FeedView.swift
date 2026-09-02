import SwiftUI

private let feedPollInterval: Duration = .seconds(25)

struct FeedView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: FeedViewModel?
    @State private var hasAppearedOnce = false
    @State private var isVisible = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Bump")
                .appRouteDestinations()
        }
        .task {
            if viewModel == nil {
                viewModel = FeedViewModel(postService: environment.postService)
            }
            await viewModel?.loadInitialIfNeeded()
        }
        .onAppear {
            isVisible = true
            if hasAppearedOnce {
                Task { await viewModel?.refreshIfStale() }
            }
            hasAppearedOnce = true
        }
        .onDisappear { isVisible = false }
        .onChange(of: environment.feedRefreshSignal.version) { _, _ in
            Task { await viewModel?.reload() }
        }
        .task(id: "\(isVisible)-\(scenePhase == .active)-\(viewModel?.sort.rawValue ?? "")") {
            guard isVisible, scenePhase == .active, viewModel?.sort == .latest else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: feedPollInterval)
                if Task.isCancelled { return }
                await viewModel?.checkForNewPosts()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let viewModel {
            FeedListView(viewModel: viewModel)
        } else {
            LoadingView()
        }
    }
}

private struct FeedListView: View {
    @Bindable var viewModel: FeedViewModel
    private let topAnchor = "feed-top"

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                LoadingView()
            } else if let errorMessage = viewModel.errorMessage, viewModel.posts.isEmpty {
                ErrorStateView(message: errorMessage) { Task { await viewModel.reload() } }
            } else {
                ScrollViewReader { scrollProxy in
                    List {
                        Section {
                            Picker("Sort", selection: $viewModel.sort) {
                                ForEach(FeedSort.allCases) { sort in
                                    Text(sort.displayName).tag(sort)
                                }
                            }
                            .pickerStyle(.segmented)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                        .id(topAnchor)

                        if viewModel.posts.isEmpty {
                            EmptyStateView(
                                icon: "photo.on.rectangle.angled",
                                title: String(localized: "No posts yet"),
                                message: String(localized: "Be the first to share a spot.")
                            )
                            .listRowSeparator(.hidden)
                        } else {
                            ForEach(viewModel.posts) { item in
                                PostRowView(item: item)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                    .task { await viewModel.loadMoreIfNeeded(currentItem: item) }
                            }
                            if viewModel.isLoadingMore {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(BumpColor.surface)
                    .refreshable { await viewModel.reload() }
                    .safeAreaInset(edge: .top) {
                        if viewModel.hasNewPosts {
                            NewPostsPill {
                                Task {
                                    await viewModel.reload()
                                    withAnimation(BumpMotion.standard) {
                                        scrollProxy.scrollTo(topAnchor, anchor: .top)
                                    }
                                }
                            }
                            .padding(.top, BumpSpacing.s)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                    .animation(BumpMotion.standard, value: viewModel.hasNewPosts)
                }
            }
        }
    }
}

private struct NewPostsPill: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("New posts", systemImage: "arrow.up.circle.fill")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, BumpSpacing.m)
                .padding(.vertical, BumpSpacing.s)
                .background(BumpColor.brand, in: Capsule())
                .foregroundStyle(.white)
                .shadow(radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}
