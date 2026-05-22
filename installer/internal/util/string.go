package util

func UniqueStrings(values []string) []string {
	seen := make(map[string]struct{})
	var result []string

	for _, value := range values {
		if value == "" {
			continue
		}
		if _, exists := seen[value]; exists {
			continue
		}
		seen[value] = struct{}{}
		result = append(result, value)
	}

	return result
}