import SwiftUI
import SwiftChat

struct AuthView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    
    @State private var isLogin = true
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    
    var body: some View {
        NavigationStack {
            if viewModel.isLoading {
                ProgressView()
            } else {
                VStack(spacing: 16) {
                    Picker("", selection: $isLogin) {
                        Text("Login").tag(true)
                        Text("Sign Up").tag(false)
                    }
                    .pickerStyle(.segmented)
                    
                    if !isLogin {
                        TextField("Full name", text: $fullName)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                    
                    if !isLogin {
                        Button {
                            showImagePicker = true
                        } label: {
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            } else {
                                Text("Select Profile Picture")
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    Button(isLogin ? "Login" : "Sign Up") {
                        Task {
                            if isLogin {
                                await viewModel.login(email: email, password: password)
                            } else {
                                var avatarUrl: String? = nil
                                if let img = selectedImage {
                                    let fileName = UUID().uuidString
                                    do {
                                        avatarUrl = try await viewModel.uploadAvatar(image: img, fileName: fileName)
                                    } catch {
                                        let nsError = error as NSError
                                        viewModel.errorMessage = "\(nsError.domain) (\(nsError.code))"
                                        return
                                    }
                                }
                                await viewModel.signUp(fullName: fullName, email: email, password: password, avatarPath: avatarUrl)
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(email.isEmpty || password.isEmpty || (!isLogin && fullName.isEmpty))
                    
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                    }
                    
                    Spacer()
                }
                .padding()
                .sheet(isPresented: $showImagePicker) {
                    SwiftChat.ImagePicker(image: $selectedImage)
                }
            }
        }
    }
}
