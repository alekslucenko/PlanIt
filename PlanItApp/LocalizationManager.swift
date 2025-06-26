import Foundation
import SwiftUI

// MARK: - Supported Languages
enum SupportedLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case spanish = "es" 
    case chinese = "zh"
    case german = "de"
    case italian = "it"
    case french = "fr"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .chinese: return "中文"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .french: return "Français"
        }
    }
    
    var nativeName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .chinese: return "中文"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .french: return "Français"
        }
    }
    
    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .chinese: return "🇨🇳"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .french: return "🇫🇷"
        }
    }
}

// MARK: - Localization Manager
@MainActor
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: SupportedLanguage {
        didSet {
            saveLanguagePreference()
            NotificationCenter.default.post(name: .languageChanged, object: currentLanguage)
        }
    }
    
    private let userDefaults = UserDefaults.standard
    private let languageKey = "app_language"
    
    private init() {
        // Load saved language or default to English
        if let savedLanguage = userDefaults.string(forKey: languageKey),
           let language = SupportedLanguage(rawValue: savedLanguage) {
            self.currentLanguage = language
        } else {
            // Try to detect system language
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            self.currentLanguage = SupportedLanguage(rawValue: systemLanguage) ?? .english
        }
    }
    
    func setLanguage(_ language: SupportedLanguage) {
        currentLanguage = language
    }
    
    private func saveLanguagePreference() {
        userDefaults.set(currentLanguage.rawValue, forKey: languageKey)
    }
    
    nonisolated func localizedString(for key: String) -> String {
        let currentLang = Task { @MainActor in currentLanguage }
        let language = Task { @MainActor in await currentLang.value }
        
        // For now, use synchronous access with fallback
        return getBuiltInTranslation(for: key, language: getCurrentLanguageSync()) ?? key
    }
    
    private nonisolated func getCurrentLanguageSync() -> SupportedLanguage {
        if let savedLanguage = UserDefaults.standard.string(forKey: languageKey),
           let language = SupportedLanguage(rawValue: savedLanguage) {
            return language
        }
        return .english
    }
    
    private nonisolated func getBundle() -> Bundle? {
        let language = getCurrentLanguageSync()
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return nil
        }
        return bundle
    }
    
    // Built-in translations for immediate functionality
    private nonisolated func getBuiltInTranslation(for key: String, language: SupportedLanguage) -> String? {
        let translations: [SupportedLanguage: [String: String]] = [
            .english: englishTranslations,
            .spanish: spanishTranslations,
            .chinese: chineseTranslations,
            .german: germanTranslations,
            .italian: italianTranslations,
            .french: frenchTranslations
        ]
        
        return translations[language]?[key]
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
}

// MARK: - String Extension for Localization
extension String {
    var localized: String {
        return LocalizationManager.shared.localizedString(for: self)
    }
    
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}

// MARK: - Built-in Translations
private let englishTranslations: [String: String] = [
    // Profile & Settings
    "profile": "Profile",
    "settings": "Settings",
    "language": "Language",
    "select_language": "Select Language",
    "account": "Account",
    "account_info": "Account Info",
    "sync_status": "Sync Status",
    "data_synced_to_cloud": "Data synced to cloud",
    "sign_out": "Sign Out",
    "sign_out_description": "Sign out of your account",
    "sign_in": "Sign In",
    "sign_in_to_planit": "Sign In to PlanIt",
    "sync_preferences": "Sync your preferences across devices",
    "advanced_settings": "Advanced Settings",
    "advanced_settings_description": "More theme and preference options",
    "notifications": "Notifications",
    "notifications_description": "Manage your notifications",
    "location_services": "Location Services",
    "location_services_description": "Control location access",
    "favorites_sync": "Favorites Sync",
    "favorites_sync_description": "Sync across devices",
    "welcome": "Welcome!",
    "welcome_back": "Welcome back!",
    "customize_experience": "Customize your PlanIt experience",
    "member_since": "Member since %@",
    "you_are_not_signed_in": "You are not signed in",
    "sign_in_or_create_account": "Sign In or Create Account",
    
    // Location Permissions
    "location_access_granted": "Location access granted",
    "location_access_denied": "Location access denied",
    "tap_to_enable_location": "Tap to enable location access",
    "location_access_restricted": "Location access restricted",
    "unknown_location_status": "Unknown location status",
    
    // Theme
    "appearance": "Appearance",
    "dark_mode": "Dark Mode",
    "light_mode": "Light Mode",
    
    // Friends
    "friends": "Friends",
    "add_friend": "Add Friend",
    "find_friends": "Find Friends",
    "my_profile": "My Profile",
    "copied_to_clipboard": "Copied to clipboard!",
    "how_to_find_friends": "How to find friends:",
    "ask_for_username": "Ask them for their username#1234",
    "copy_from_profile": "They can copy it from their profile",
    "enter_to_send_request": "Enter it here to send a friend request",
    "usernames_format": "Usernames are letters & numbers only (no spaces)",
    "cancel": "Cancel",
    "ok": "OK",
    "sending": "Sending...",
    "send_friend_request": "Send Friend Request",
    
    // Chat & Messages
    "messages": "Messages",
    "chat": "Chat",
    "new_message": "New Message",
    "type_message": "Type a message...",
    "send": "Send",
    "reply": "Reply",
    "loading_conversations": "Loading conversations...",
    "no_conversations": "No conversations yet",
    "start_chatting": "Start chatting with your friends!",
    "ping": "Ping!",
    "tap_to_open_chat": "Tap to open chat",
    
    // Notifications
    "friend_request": "Friend Request",
    "friend_request_accepted": "Friend Request Accepted",
    "new_recommendation": "New Recommendation",
    "system_alert": "System Alert",
    "accept": "Accept",
    "decline": "Decline",
    "view_chat": "View Chat",
    
    // Onboarding
    "username_requirements": "Username must be at least 3 characters",
    "username_too_long": "Username must be 20 characters or less",
    "only_letters_numbers": "Only letters and numbers allowed",
    "already_have_account": "Already have an account?",
    "continue": "Continue",
    
    // General
    "done": "Done",
    "save": "Save",
    "reset": "Reset",
    "clear": "Clear",
    "copied": "Copied!",
    "loading": "Loading...",
    "error": "Error",
    "success": "Success",
    "failed": "Failed",
    "unknown_user": "Unknown User",
    "no_email": "No email",
]

private let spanishTranslations: [String: String] = [
    // Profile & Settings
    "profile": "Perfil",
    "settings": "Configuración",
    "language": "Idioma",
    "select_language": "Seleccionar idioma",
    "account": "Cuenta",
    "account_info": "Información de cuenta",
    "sync_status": "Estado de sincronización",
    "data_synced_to_cloud": "Datos sincronizados en la nube",
    "sign_out": "Cerrar sesión",
    "sign_out_description": "Cerrar sesión de tu cuenta",
    "sign_in": "Iniciar sesión",
    "sign_in_to_planit": "Iniciar sesión en PlanIt",
    "sync_preferences": "Sincroniza tus preferencias en todos los dispositivos",
    "advanced_settings": "Configuración avanzada",
    "advanced_settings_description": "Más opciones de tema y preferencias",
    "notifications": "Notificaciones",
    "notifications_description": "Administrar tus notificaciones",
    "location_services": "Servicios de ubicación",
    "location_services_description": "Controlar acceso a ubicación",
    "favorites_sync": "Sincronización de favoritos",
    "favorites_sync_description": "Sincronizar en todos los dispositivos",
    "welcome": "¡Bienvenido!",
    "welcome_back": "¡Bienvenido de vuelta!",
    "customize_experience": "Personaliza tu experiencia PlanIt",
    "member_since": "Miembro desde %@",
    "you_are_not_signed_in": "No has iniciado sesión",
    "sign_in_or_create_account": "Iniciar sesión o crear cuenta",
    
    // Location Permissions
    "location_access_granted": "Acceso a ubicación concedido",
    "location_access_denied": "Acceso a ubicación denegado",
    "tap_to_enable_location": "Toca para habilitar acceso a ubicación",
    "location_access_restricted": "Acceso a ubicación restringido",
    "unknown_location_status": "Estado de ubicación desconocido",
    
    // Theme
    "appearance": "Apariencia",
    "dark_mode": "Modo oscuro",
    "light_mode": "Modo claro",
    
    // Friends
    "friends": "Amigos",
    "add_friend": "Agregar amigo",
    "find_friends": "Encontrar amigos",
    "my_profile": "Mi perfil",
    "copied_to_clipboard": "¡Copiado al portapapeles!",
    "how_to_find_friends": "Cómo encontrar amigos:",
    "ask_for_username": "Pídeles su nombre de usuario#1234",
    "copy_from_profile": "Pueden copiarlo desde su perfil",
    "enter_to_send_request": "Ingrésalo aquí para enviar solicitud de amistad",
    "usernames_format": "Los nombres de usuario solo tienen letras y números (sin espacios)",
    "cancel": "Cancelar",
    "ok": "OK",
    
    // Chat & Messages
    "messages": "Mensajes",
    "chat": "Chat",
    "new_message": "Nuevo mensaje",
    "type_message": "Escribe un mensaje...",
    "send": "Enviar",
    "reply": "Responder",
    "loading_conversations": "Cargando conversaciones...",
    "no_conversations": "Aún no hay conversaciones",
    "start_chatting": "¡Comienza a chatear con tus amigos!",
    "ping": "¡Ping!",
    "tap_to_open_chat": "Toca para abrir chat",
    
    // Notifications
    "friend_request": "Solicitud de amistad",
    "friend_request_accepted": "Solicitud de amistad aceptada",
    "new_recommendation": "Nueva recomendación",
    "system_alert": "Alerta del sistema",
    "accept": "Aceptar",
    "decline": "Rechazar",
    "view_chat": "Ver chat",
    
    // Onboarding
    "username_requirements": "El nombre de usuario debe tener al menos 3 caracteres",
    "username_too_long": "El nombre de usuario debe tener 20 caracteres o menos",
    "only_letters_numbers": "Solo se permiten letras y números",
    "already_have_account": "¿Ya tienes una cuenta?",
    "continue": "Continuar",
    
    // General
    "done": "Hecho",
    "save": "Guardar",
    "reset": "Restablecer",
    "clear": "Limpiar",
    "copied": "¡Copiado!",
    "loading": "Cargando...",
    "error": "Error",
    "success": "Éxito",
    "failed": "Falló",
    "unknown_user": "Usuario desconocido",
    "no_email": "Sin email",
]

private let chineseTranslations: [String: String] = [
    // Profile & Settings
    "profile": "个人资料",
    "settings": "设置",
    "language": "语言",
    "select_language": "选择语言",
    "account": "账户",
    "account_info": "账户信息",
    "sync_status": "同步状态",
    "data_synced_to_cloud": "数据已同步到云端",
    "sign_out": "退出登录",
    "sign_out_description": "退出您的账户",
    "sign_in": "登录",
    "sign_in_to_planit": "登录 PlanIt",
    "sync_preferences": "在设备间同步您的偏好设置",
    "advanced_settings": "高级设置",
    "advanced_settings_description": "更多主题和偏好选项",
    "notifications": "通知",
    "notifications_description": "管理您的通知",
    "location_services": "定位服务",
    "location_services_description": "控制位置访问",
    "favorites_sync": "收藏同步",
    "favorites_sync_description": "跨设备同步",
    "welcome": "欢迎！",
    "welcome_back": "欢迎回来！",
    "customize_experience": "定制您的 PlanIt 体验",
    "member_since": "注册时间 %@",
    "you_are_not_signed_in": "您还未登录",
    "sign_in_or_create_account": "登录或创建账户",
    
    // Location Permissions
    "location_access_granted": "已授予位置访问权限",
    "location_access_denied": "位置访问被拒绝",
    "tap_to_enable_location": "点击启用位置访问",
    "location_access_restricted": "位置访问受限",
    "unknown_location_status": "未知位置状态",
    
    // Theme
    "appearance": "外观",
    "dark_mode": "深色模式",
    "light_mode": "浅色模式",
    
    // Friends
    "friends": "朋友",
    "add_friend": "添加朋友",
    "find_friends": "查找朋友",
    "my_profile": "我的资料",
    "copied_to_clipboard": "已复制到剪贴板！",
    "how_to_find_friends": "如何查找朋友：",
    "ask_for_username": "向他们索要用户名#1234",
    "copy_from_profile": "他们可以从个人资料中复制",
    "enter_to_send_request": "在此输入以发送好友请求",
    "usernames_format": "用户名只能包含字母和数字（无空格）",
    "cancel": "取消",
    "ok": "确定",
    
    // Chat & Messages
    "messages": "消息",
    "chat": "聊天",
    "new_message": "新消息",
    "type_message": "输入消息...",
    "send": "发送",
    "reply": "回复",
    "loading_conversations": "正在加载对话...",
    "no_conversations": "暂无对话",
    "start_chatting": "开始与朋友聊天！",
    "ping": "Ping！",
    "tap_to_open_chat": "点击打开聊天",
    
    // Notifications
    "friend_request": "好友请求",
    "friend_request_accepted": "好友请求已接受",
    "new_recommendation": "新推荐",
    "system_alert": "系统提醒",
    "accept": "接受",
    "decline": "拒绝",
    "view_chat": "查看聊天",
    
    // Onboarding
    "username_requirements": "用户名至少需要3个字符",
    "username_too_long": "用户名不能超过20个字符",
    "only_letters_numbers": "只允许字母和数字",
    "already_have_account": "已有账户？",
    "continue": "继续",
    
    // General
    "done": "完成",
    "save": "保存",
    "reset": "重置",
    "clear": "清除",
    "copied": "已复制！",
    "loading": "正在加载...",
    "error": "错误",
    "success": "成功",
    "failed": "失败",
    "unknown_user": "未知用户",
    "no_email": "无邮箱",
]

private let germanTranslations: [String: String] = [
    // Profile & Settings
    "profile": "Profil",
    "settings": "Einstellungen",
    "language": "Sprache",
    "select_language": "Sprache auswählen",
    "account": "Konto",
    "account_info": "Kontoinformationen",
    "sync_status": "Sync-Status",
    "data_synced_to_cloud": "Daten mit Cloud synchronisiert",
    "sign_out": "Abmelden",
    "sign_out_description": "Von Ihrem Konto abmelden",
    "sign_in": "Anmelden",
    "sign_in_to_planit": "Bei PlanIt anmelden",
    "sync_preferences": "Synchronisieren Sie Ihre Einstellungen auf allen Geräten",
    "advanced_settings": "Erweiterte Einstellungen",
    "advanced_settings_description": "Weitere Theme- und Präferenzoptionen",
    "notifications": "Benachrichtigungen",
    "notifications_description": "Verwalten Sie Ihre Benachrichtigungen",
    "location_services": "Standortdienste",
    "location_services_description": "Standortzugriff kontrollieren",
    "favorites_sync": "Favoriten-Sync",
    "favorites_sync_description": "Geräteübergreifend synchronisieren",
    "welcome": "Willkommen!",
    "welcome_back": "Willkommen zurück!",
    "customize_experience": "Passen Sie Ihr PlanIt-Erlebnis an",
    "member_since": "Mitglied seit %@",
    "you_are_not_signed_in": "Sie sind nicht angemeldet",
    "sign_in_or_create_account": "Anmelden oder Konto erstellen",
    
    // Location Permissions
    "location_access_granted": "Standortzugriff gewährt",
    "location_access_denied": "Standortzugriff verweigert",
    "tap_to_enable_location": "Tippen um Standortzugriff zu aktivieren",
    "location_access_restricted": "Standortzugriff eingeschränkt",
    "unknown_location_status": "Unbekannter Standortstatus",
    
    // Theme
    "appearance": "Aussehen",
    "dark_mode": "Dunkler Modus",
    "light_mode": "Heller Modus",
    
    // Friends
    "friends": "Freunde",
    "add_friend": "Freund hinzufügen",
    "find_friends": "Freunde finden",
    "my_profile": "Mein Profil",
    "copied_to_clipboard": "In Zwischenablage kopiert!",
    "how_to_find_friends": "So finden Sie Freunde:",
    "ask_for_username": "Fragen Sie nach ihrem Benutzernamen#1234",
    "copy_from_profile": "Sie können ihn von ihrem Profil kopieren",
    "enter_to_send_request": "Hier eingeben um Freundschaftsanfrage zu senden",
    "usernames_format": "Benutzernamen enthalten nur Buchstaben und Zahlen (keine Leerzeichen)",
    "cancel": "Abbrechen",
    "ok": "OK",
    
    // Chat & Messages
    "messages": "Nachrichten",
    "chat": "Chat",
    "new_message": "Neue Nachricht",
    "type_message": "Nachricht eingeben...",
    "send": "Senden",
    "reply": "Antworten",
    "loading_conversations": "Lade Unterhaltungen...",
    "no_conversations": "Noch keine Unterhaltungen",
    "start_chatting": "Beginnen Sie zu chatten mit Ihren Freunden!",
    "ping": "Ping!",
    "tap_to_open_chat": "Tippen um Chat zu öffnen",
    
    // Notifications
    "friend_request": "Freundschaftsanfrage",
    "friend_request_accepted": "Freundschaftsanfrage angenommen",
    "new_recommendation": "Neue Empfehlung",
    "system_alert": "Systembenachrichtigung",
    "accept": "Annehmen",
    "decline": "Ablehnen",
    "view_chat": "Chat anzeigen",
    
    // Onboarding
    "username_requirements": "Benutzername muss mindestens 3 Zeichen haben",
    "username_too_long": "Benutzername darf höchstens 20 Zeichen haben",
    "only_letters_numbers": "Nur Buchstaben und Zahlen erlaubt",
    "already_have_account": "Haben Sie bereits ein Konto?",
    "continue": "Weiter",
    
    // General
    "done": "Fertig",
    "save": "Speichern",
    "reset": "Zurücksetzen",
    "clear": "Löschen",
    "copied": "Kopiert!",
    "loading": "Lade...",
    "error": "Fehler",
    "success": "Erfolg",
    "failed": "Fehlgeschlagen",
    "unknown_user": "Unbekannter Benutzer",
    "no_email": "Keine E-Mail",
]

private let italianTranslations: [String: String] = [
    // Profile & Settings
    "profile": "Profilo",
    "settings": "Impostazioni",
    "language": "Lingua",
    "select_language": "Seleziona lingua",
    "account": "Account",
    "account_info": "Informazioni account",
    "sync_status": "Stato sincronizzazione",
    "data_synced_to_cloud": "Dati sincronizzati nel cloud",
    "sign_out": "Disconnetti",
    "sign_out_description": "Disconnetti dal tuo account",
    "sign_in": "Accedi",
    "sign_in_to_planit": "Accedi a PlanIt",
    "sync_preferences": "Sincronizza le tue preferenze su tutti i dispositivi",
    "advanced_settings": "Impostazioni avanzate",
    "advanced_settings_description": "Più opzioni per tema e preferenze",
    "notifications": "Notifiche",
    "notifications_description": "Gestisci le tue notifiche",
    "location_services": "Servizi di localizzazione",
    "location_services_description": "Controlla accesso alla posizione",
    "favorites_sync": "Sincronizzazione preferiti",
    "favorites_sync_description": "Sincronizza su tutti i dispositivi",
    "welcome": "Benvenuto!",
    "welcome_back": "Bentornato!",
    "customize_experience": "Personalizza la tua esperienza PlanIt",
    "member_since": "Membro dal %@",
    "you_are_not_signed_in": "Non hai effettuato l'accesso",
    "sign_in_or_create_account": "Accedi o crea un account",
    
    // Location Permissions
    "location_access_granted": "Accesso alla posizione concesso",
    "location_access_denied": "Accesso alla posizione negato",
    "tap_to_enable_location": "Tocca per abilitare accesso alla posizione",
    "location_access_restricted": "Accesso alla posizione limitato",
    "unknown_location_status": "Stato posizione sconosciuto",
    
    // Theme
    "appearance": "Aspetto",
    "dark_mode": "Modalità scura",
    "light_mode": "Modalità chiara",
    
    // Friends
    "friends": "Amici",
    "add_friend": "Aggiungi amico",
    "find_friends": "Trova amici",
    "my_profile": "Il mio profilo",
    "copied_to_clipboard": "Copiato negli appunti!",
    "how_to_find_friends": "Come trovare amici:",
    "ask_for_username": "Chiedi il loro nome utente#1234",
    "copy_from_profile": "Possono copiarlo dal loro profilo",
    "enter_to_send_request": "Inseriscilo qui per inviare richiesta di amicizia",
    "usernames_format": "I nomi utente contengono solo lettere e numeri (nessuno spazio)",
    "cancel": "Annulla",
    "ok": "OK",
    
    // Chat & Messages
    "messages": "Messaggi",
    "chat": "Chat",
    "new_message": "Nuovo messaggio",
    "type_message": "Scrivi un messaggio...",
    "send": "Invia",
    "reply": "Rispondi",
    "loading_conversations": "Caricamento conversazioni...",
    "no_conversations": "Nessuna conversazione ancora",
    "start_chatting": "Inizia a chattare con i tuoi amici!",
    "ping": "Ping!",
    "tap_to_open_chat": "Tocca per aprire chat",
    
    // Notifications
    "friend_request": "Richiesta di amicizia",
    "friend_request_accepted": "Richiesta di amicizia accettata",
    "new_recommendation": "Nuova raccomandazione",
    "system_alert": "Avviso di sistema",
    "accept": "Accetta",
    "decline": "Rifiuta",
    "view_chat": "Visualizza chat",
    
    // Onboarding
    "username_requirements": "Il nome utente deve avere almeno 3 caratteri",
    "username_too_long": "Il nome utente deve avere al massimo 20 caratteri",
    "only_letters_numbers": "Solo lettere e numeri consentiti",
    "already_have_account": "Hai già un account?",
    "continue": "Continua",
    
    // General
    "done": "Fatto",
    "save": "Salva",
    "reset": "Ripristina",
    "clear": "Cancella",
    "copied": "Copiato!",
    "loading": "Caricamento...",
    "error": "Errore",
    "success": "Successo",
    "failed": "Fallito",
    "unknown_user": "Utente sconosciuto",
    "no_email": "Nessuna email",
]

private let frenchTranslations: [String: String] = [
    // Profile & Settings
    "profile": "Profil",
    "settings": "Paramètres",
    "language": "Langue",
    "select_language": "Sélectionner la langue",
    "account": "Compte",
    "account_info": "Informations du compte",
    "sync_status": "État de synchronisation",
    "data_synced_to_cloud": "Données synchronisées dans le cloud",
    "sign_out": "Se déconnecter",
    "sign_out_description": "Se déconnecter de votre compte",
    "sign_in": "Se connecter",
    "sign_in_to_planit": "Se connecter à PlanIt",
    "sync_preferences": "Synchronisez vos préférences sur tous les appareils",
    "advanced_settings": "Paramètres avancés",
    "advanced_settings_description": "Plus d'options de thème et de préférences",
    "notifications": "Notifications",
    "notifications_description": "Gérez vos notifications",
    "location_services": "Services de localisation",
    "location_services_description": "Contrôler l'accès à la localisation",
    "favorites_sync": "Synchronisation des favoris",
    "favorites_sync_description": "Synchroniser sur tous les appareils",
    "welcome": "Bienvenue !",
    "welcome_back": "Bon retour !",
    "customize_experience": "Personnalisez votre expérience PlanIt",
    "member_since": "Membre depuis %@",
    "you_are_not_signed_in": "Vous n'êtes pas connecté",
    "sign_in_or_create_account": "Se connecter ou créer un compte",
    
    // Location Permissions
    "location_access_granted": "Accès à la localisation accordé",
    "location_access_denied": "Accès à la localisation refusé",
    "tap_to_enable_location": "Appuyez pour activer l'accès à la localisation",
    "location_access_restricted": "Accès à la localisation restreint",
    "unknown_location_status": "État de localisation inconnu",
    
    // Theme
    "appearance": "Apparence",
    "dark_mode": "Mode sombre",
    "light_mode": "Mode clair",
    
    // Friends
    "friends": "Amis",
    "add_friend": "Ajouter un ami",
    "find_friends": "Trouver des amis",
    "my_profile": "Mon profil",
    "copied_to_clipboard": "Copié dans le presse-papiers !",
    "how_to_find_friends": "Comment trouver des amis :",
    "ask_for_username": "Demandez-leur leur nom d'utilisateur#1234",
    "copy_from_profile": "Ils peuvent le copier depuis leur profil",
    "enter_to_send_request": "Entrez-le ici pour envoyer une demande d'ami",
    "usernames_format": "Les noms d'utilisateur ne contiennent que des lettres et des chiffres (pas d'espaces)",
    "cancel": "Annuler",
    "ok": "OK",
    
    // Chat & Messages
    "messages": "Messages",
    "chat": "Chat",
    "new_message": "Nouveau message",
    "type_message": "Tapez un message...",
    "send": "Envoyer",
    "reply": "Répondre",
    "loading_conversations": "Chargement des conversations...",
    "no_conversations": "Aucune conversation encore",
    "start_chatting": "Commencez à discuter avec vos amis !",
    "ping": "Ping !",
    "tap_to_open_chat": "Appuyez pour ouvrir le chat",
    
    // Notifications
    "friend_request": "Demande d'ami",
    "friend_request_accepted": "Demande d'ami acceptée",
    "new_recommendation": "Nouvelle recommandation",
    "system_alert": "Alerte système",
    "accept": "Accepter",
    "decline": "Refuser",
    "view_chat": "Voir le chat",
    
    // Onboarding
    "username_requirements": "Le nom d'utilisateur doit avoir au moins 3 caractères",
    "username_too_long": "Le nom d'utilisateur doit avoir au maximum 20 caractères",
    "only_letters_numbers": "Seules les lettres et les chiffres sont autorisés",
    "already_have_account": "Vous avez déjà un compte ?",
    "continue": "Continuer",
    
    // General
    "done": "Terminé",
    "save": "Sauvegarder",
    "reset": "Réinitialiser",
    "clear": "Effacer",
    "copied": "Copié !",
    "loading": "Chargement...",
    "error": "Erreur",
    "success": "Succès",
    "failed": "Échoué",
    "unknown_user": "Utilisateur inconnu",
    "no_email": "Aucun email",
] 