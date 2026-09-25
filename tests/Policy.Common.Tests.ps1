BeforeAll {
    . "$PSScriptRoot/../scripts/Policy.Common.ps1"
}

Describe "Assert-ExpirationPolicy" {
    It "accepts normal values" {
        { Assert-ExpirationPolicy -RecommendedDays 30 -MaxDays 180 } |
            Should -Not -Throw
    }

    It "rejects recommended below 7" {
        { Assert-ExpirationPolicy -RecommendedDays 6 -MaxDays 180 } |
            Should -Throw
    }

    It "rejects max above 720" {
        { Assert-ExpirationPolicy -RecommendedDays 30 -MaxDays 721 } |
            Should -Throw
    }

    It "rejects recommended greater than max" {
        { Assert-ExpirationPolicy -RecommendedDays 181 -MaxDays 180 } |
            Should -Throw
    }
}

Describe "Get-ManagedState" {
    It "returns empty state when file does not exist" {
        $temp = Join-Path $TestDrive "missing.json"

        $state = Get-ManagedState `
            -Path $temp `
            -GroupId "11111111-1111-1111-1111-111111111111"

        $state.GroupId | Should -Be "11111111-1111-1111-1111-111111111111"
        @($state.Sites).Count | Should -Be 0
    }
}
