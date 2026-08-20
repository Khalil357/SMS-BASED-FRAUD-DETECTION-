package com.example.smsfraud.config;

import com.example.smsfraud.entity.User;
import lombok.RequiredArgsConstructor;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.oauth2.core.user.OAuth2User;

import java.util.Collection;
import java.util.Collections;
import java.util.Map;


@RequiredArgsConstructor
public class CustomUserDetails implements UserDetails, OAuth2User {
    
    private final User user; // final field to hold the User entity
    private Map<String, Object> attributes;

    // constructor to initialize the user field for UserDetails during email - password authentication
    public CustomUserDetails(User user) {
        this.user = user; 
    }

    // constructor to initialize both the user and attributes fields for OAuth2User
    public CustomUserDetails(User user, Map<String, Object> attributes) {
        this.user = user; 
        this.attributes = attributes;
    }

    // method to get the authorities granted to the user
    public Collection<? extends GrantedAuthority> getAuthorities() {
    return Collections.singletonList(
            new SimpleGrantedAuthority("ROLE_" + user.getRole().name())
        );
    }

    // method to get the hashed password of the user
    @Override
    public String getPassword() {
        return user.getPasswordHash();
    }

    // method to get the username of the user, which is the email in this case
    @Override
    public String getUsername() {
        return user.getEmail();
    }

    @Override
    public boolean isAccountNonExpired() {
        // Always true - accounts never expire in this implementation
        return true;
    }

    // method to check if the account is not locked, returns true if the account is not locked
    @Override
    public boolean isAccountNonLocked() {
        return !user.getIsLocked();
    }

    @Override
    public boolean isCredentialsNonExpired() {
        // Always true - passwords never expire in this implementation
        return true;
    }

    @Override
    public boolean isEnabled() {
        // Account must be BOTH active AND verified to log in
        return user.getIsActive() && user.getIsVerified();
    }

    // method to get the attributes of the OAuth2User, returns the attributes map
    @Override
    public Map<String, Object> getAttributes() {
        return attributes;
    }

    // method to get the name of the OAuth2User, returns the email of the user
    @Override
    public String getName() {
        return user.getEmail();
    }

    // Returns original User entity
    public User getUser() {
        return user;
    }

}

