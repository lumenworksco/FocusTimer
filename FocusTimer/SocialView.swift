import SwiftUI

struct SocialView: View {
    @StateObject private var vm = SocialViewModel()

    var body: some View {
        Group {
            switch vm.state {
            case .notConfigured: notConfiguredView
            case .loading:       loadingView
            case .setup:         setupView
            case .main:          mainView
            }
        }
        .frame(width: 380, height: 440)
        .onAppear { vm.load() }
    }

    // MARK: - States

    private var notConfiguredView: some View {
        VStack(spacing: 16) {
            Image(systemName: "network.slash")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text("Supabase not configured")
                .font(.headline)
            Text("Fill in your project URL and anon key\nin SupabaseConfig.swift, then rebuild.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Connecting…")
                .foregroundStyle(.secondary)
                .font(.callout)
        }
    }

    private var setupView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 40))
                .foregroundStyle(.red)

            VStack(spacing: 6) {
                Text("Join the social layer")
                    .font(.title3.bold())
                Text("Pick a username so friends can find you.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .multilineTextAlignment(.center)
            }

            TextField("username", text: $vm.usernameInput)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 220)
                .autocorrectionDisabled()
                .onSubmit { vm.createProfile() }

            if let err = vm.errorMessage {
                Text(err).foregroundStyle(.red).font(.caption)
            }

            Button("Get Started") { vm.createProfile() }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(vm.isLoading || vm.usernameInput.trimmingCharacters(in: .whitespaces).isEmpty)

            if vm.isLoading { ProgressView().scaleEffect(0.7) }
        }
        .padding(32)
    }

    private var mainView: some View {
        VStack(spacing: 0) {
            myHeader
            Divider()
            friendList
            Divider()
            addFriendBar
        }
    }

    // MARK: - Main sub-views

    private var myHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("@\(vm.myProfile?.username ?? "–")")
                    .font(.headline)
                HStack(spacing: 16) {
                    statPill("\(vm.todaySessions)", "sessions")
                    statPill("\(vm.todayMinutes)", "min")
                    statPill("\(vm.streak)", "day streak")
                }
            }
            Spacer()
            if vm.isLoading { ProgressView().scaleEffect(0.6) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func statPill(_ value: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(value).fontWeight(.semibold)
            Text(label).foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private var friendList: some View {
        List {
            if vm.friends.isEmpty && !vm.isLoading {
                Text("No friends yet — add one below.")
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                    .listRowSeparator(.hidden)
            }
            ForEach(vm.friends) { friend in
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("@\(friend.profile.username)")
                            .font(.subheadline.weight(.medium))
                        HStack(spacing: 12) {
                            Text("\(friend.todaySessions) sessions today")
                            Text("\(friend.todayMinutes) min")
                            Text("\(friend.weekSessions) this week")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .onDelete { vm.removeFriends(at: $0) }
        }
        .listStyle(.plain)
    }

    private var addFriendBar: some View {
        VStack(spacing: 0) {
            if let err = vm.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 8) {
                TextField("Find by username", text: $vm.addInput)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .onSubmit { vm.addFriend() }
                Button("Add") { vm.addFriend() }
                    .buttonStyle(.bordered)
                    .disabled(vm.addInput.trimmingCharacters(in: .whitespaces).isEmpty || vm.isLoading)
            }
            .padding(12)
        }
    }
}

// MARK: - ViewModel

@MainActor
final class SocialViewModel: ObservableObject {
    enum State { case notConfigured, loading, setup, main }

    @Published var state: State = .loading
    @Published var myProfile: Profile?
    @Published var friends: [FriendWithStats] = []
    @Published var usernameInput = ""
    @Published var addInput = ""
    @Published var errorMessage: String?
    @Published var isLoading = false

    var todaySessions: Int    { StatsStore.shared.todaySessions    }
    var todayMinutes: Int     { StatsStore.shared.todayFocusMinutes }
    var streak: Int           { StatsStore.shared.currentStreak    }

    func load() {
        guard SupabaseConfig.isConfigured else { state = .notConfigured; return }
        Task {
            isLoading = true
            defer { isLoading = false }
            do {
                try await SupabaseManager.shared.ensureAuthenticated()
                if let p = try await SupabaseManager.shared.getMyProfile() {
                    myProfile = p
                    state = .main
                    await loadFriends()
                } else {
                    state = .setup
                }
            } catch {
                errorMessage = error.localizedDescription
                state = .setup
            }
        }
    }

    func createProfile() {
        let name = usernameInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !name.isEmpty else { return }
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                try await SupabaseManager.shared.createProfile(username: name)
                myProfile = try await SupabaseManager.shared.getMyProfile()
                state = .main
                await loadFriends()
            } catch SupabaseError.conflict {
                errorMessage = "Username already taken."
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func addFriend() {
        let name = addInput.trimmingCharacters(in: .whitespaces).lowercased()
        guard !name.isEmpty else { return }
        Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }
            do {
                guard let found = try await SupabaseManager.shared.searchProfile(username: name) else {
                    errorMessage = "User '\(name)' not found."
                    return
                }
                let myId = await SupabaseManager.shared.currentUserId
                if found.id == myId {
                    errorMessage = "That's you!"
                    return
                }
                if friends.contains(where: { $0.id == found.id }) {
                    errorMessage = "Already friends."
                    return
                }
                try await SupabaseManager.shared.addFriend(friendId: found.id)
                addInput = ""
                await loadFriends()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func removeFriends(at offsets: IndexSet) {
        let removed = offsets.map { friends[$0] }
        friends.remove(atOffsets: offsets)
        Task {
            for f in removed {
                try? await SupabaseManager.shared.removeFriend(friendId: f.id)
            }
        }
    }

    func loadFriends() async {
        do {
            let ids = try await SupabaseManager.shared.getFriendIds()
            guard !ids.isEmpty else { friends = []; return }
            let profiles = try await SupabaseManager.shared.getProfiles(ids: ids)
            let since = DateFormatter.yyyyMMdd.string(
                from: Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date()
            )
            let stats = try await SupabaseManager.shared.getStatsForUsers(ids: ids, since: since)
            let today = DateFormatter.yyyyMMdd.string(from: Date())
            friends = profiles.map { p in
                let ps = stats.filter { $0.userId == p.id }
                return FriendWithStats(
                    profile: p,
                    todaySessions: ps.first(where: { $0.date == today })?.sessions    ?? 0,
                    todayMinutes:  ps.first(where: { $0.date == today })?.focusMinutes ?? 0,
                    weekSessions:  ps.reduce(0) { $0 + $1.sessions }
                )
            }
        } catch {
            // Keep existing friend data on network failure
        }
    }
}
