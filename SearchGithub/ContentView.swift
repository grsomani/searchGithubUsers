//
//  ContentView.swift
//  SearchGithub
//
//  Created by Ganesh on 28/06/25.
//

import SwiftUI
import Combine

struct GitHubSearchResponse: Codable {
    let items: [User]
}

struct User: Identifiable, Codable {
    let id: Int
    let name: String
    let avatarURLString: String?
    
    func getAvtarURL() -> URL? {
        guard let urlString = avatarURLString else {
            return nil
        }
        return URL(string: urlString)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name = "login"
        case avatarURLString = "avatar_url"
    }
}

class UserListViewModel: ObservableObject {
    @Published var searchText: String
    @Published var userList: [User]
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()

    init(searchText: String = "", userList: [User] = []) {
        self.searchText = searchText
        self.userList = userList
        startObserving()
    }
    
    func startObserving() {
        $searchText
            .removeDuplicates()
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .filter { $0.count > 3 }
            .sink { [weak self] text in
                self?.performSearch(for: text)
            }
            .store(in: &cancellables)
    }
    
    func performSearch(for searchText: String) {
        let urlString = "https://api.github.com/search/users?q=\(searchText)"
        guard let url = URL(string: urlString) else {
            return
        }
        let urlRequest = URLRequest(url: url)
        let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.userList = []
                    self.errorMessage = "Something went wrong"
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.userList = []
                    self.errorMessage = "Something went wrong"
                }
                return
            }
            
            do {
                let list = try JSONDecoder().decode(GitHubSearchResponse.self, from: data)
                print("Response: \(list.items)")
                DispatchQueue.main.async {
                    self.errorMessage = nil
                    if list.items.isEmpty {
                        self.errorMessage = "User not found"
                    }
                    self.userList = list.items
                }
            } catch {
                print("Failed to decode JSON: \(error)")
            }
        }
        task.resume()
    }
}

struct ContentView: View {
    @StateObject var viewModel = UserListViewModel()
    
    var body: some View {
        VStack {
            TextField("Username", text: $viewModel.searchText)
                .padding(10)
                .border(Color.black, width: 2.0)
            if (viewModel.errorMessage != nil) {
                errorMessageView(viewModel.errorMessage ?? "")
            } else {
                List(viewModel.userList) { item in
                    HStack {
                        AsyncImage(url: item.getAvtarURL()) { phase in
                            phase
                                .image?.resizable()
                                .scaledToFit()
                        }
                        .frame(width: 50, height: 50)
                        .clipShape(.circle)
                        .scaledToFit()
                        Text(item.name)
                    }
                }
            }
            
        }
        .padding()
    }
    
    @ViewBuilder
    func errorMessageView(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
