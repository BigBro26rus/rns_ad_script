# Итак, что бы чудо произошло, нужно запустить файлик func.ps1
# или перенести содержимое func.ps1 в C:\Users\User\Documents\WindowsPowerShell\Microsoft.VSCode_profile.ps1

# после чего функционал должен(пхах) начать работать.
# Постралася все описать подробно, но время позднее.

# Это блок переменных которые нужны для работы функции
    $date = Get-Date -Format "yyyyMMdd"
    $log_path = "sys\$date-log.txt"
    $backup_path = "sys\backup.txt"
    $ticket_path = "ticket-out\"
    $SearchBase = "OU=users,DC=domain,DC=com"

# Патерн исключений для удаления групп
    $ExcludePattern = "group|*group*|..|.."
# Объявляем всякое нужное
    $groups1 = Get-Content -Path "var\group1.txt"
    $users_DN = Get-Content -Path "var\users_DN.txt" -Encoding UTF8
    $users_sam = Get-Content -Path "var\users_sam.txt"
#записываем тикет по которому работаем
    $ticket="123456"
# Забираем список уз которые мы включили
    $users_sam_en = Get-Content -Path "ticket-out\$ticket\enabled.txt"
# Забираем список уз которые были включены
    $users_sam_ac = Get-Content -Path "ticket-out\$ticket\active.txt"
# забираем список уз после перевода ФИО в sam или просто sam
    $users_sam = Get-Content -Path "var\users_sam.txt"

# Защита от f5
    Clear-Content -Path "var\users_sam.txt"
    $users_sam_en = ""
    $users_sam_ac = ""
    $users_sam = ""
    $users_DN = ""
    $groups1 = ""
    $ticket = ""
    $ExcludePattern = ""

# May force be with you. 

# Перегоняем ФИО в SAM
    getSamByDisplayName -DisplayName $users_DN | Out-File -FilePath "var\users_sam.txt"
# Бэкапим и файлик этот пожалуйста не чистим для истории
    backupGroups -users_sam $users_sam -ticket $ticket
# Проверяем активна УЗ или нет
    checkEnableADUsers  -Usernames $users_sam -ticket $ticket
    # Включаем выключенные УЗ
    enableADUsers -Usernames $users_sam -ticket $ticket
# Удаляем у УЗ котоыре активировали все группы кроме тех, что обозначили в блоке исключений
    #пробегаемся по тем кто был включен
    removeUsersFromAllGroups -Usernames $users_sam_en -ExcludePattern $ExcludePattern -ticket $ticket
    #по тем кого включили
    removeUsersFromAllGroups -Usernames $users_sam_ac -ExcludePattern $ExcludePattern -ticket $ticket
    #по всем кого искали
    removeUsersFromAllGroups -Usernames $users_sam -ExcludePattern $ExcludePattern -ticket $ticket
# Добаляем списку пользователей $users_sam группы из списка $groups1
    addUsersToGroups -Usernames $users_sam -Groups $groups1 -ticket $ticket
    #пробегаемся по тем кто был включен
    addUsersToGroups -Usernames $users_sam_ac -Groups $groups1 -ticket $ticket
    #по тем кого включили
    addUsersToGroups -Usernames $users_sam_en -Groups $groups1 -ticket $ticket
# Тоже что и выше только убираем группы
    dropUsersFromGroups -Usernames $users_sam -Groups $groups1 -ticket $ticket
    #пробегаемся по тем кто был включен
    dropUsersFromGroups -Usernames $users_sam_ac -Groups $groups1 -ticket $ticket
    #по тем кого включили
    dropUsersFromGroups -Usernames $users_sam_en -Groups $groups1 -ticket $ticket