package com.fieldnotes;

import com.fieldnotes.backend.entity.User;
import com.fieldnotes.backend.repository.UserRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.security.crypto.password.PasswordEncoder;

@SpringBootApplication
public class FieldNotesBackendApplication {

	public static void main(String[] args) {
		SpringApplication.run(FieldNotesBackendApplication.class, args);
	}

	@Bean
	CommandLineRunner initDefaultData(UserRepository userRepository, PasswordEncoder passwordEncoder) {
		return args -> {
			if (userRepository.findByEmail("operator@fieldnotes.com").isEmpty()) {
				User user = new User();
				user.setEmail("operator@fieldnotes.com");
				user.setPasswordHash(passwordEncoder.encode("Password123!"));
				userRepository.save(user);
				System.out.println(">>> Seeded default user: operator@fieldnotes.com / Password123!");
			}
		};
	}
}

