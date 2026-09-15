package com.example.smsfraud.user;

/**
 * Fixed set of values for a user's gender. Kept as an enum so the admin "add user"
 * form can offer a dropdown instead of free text, and so arbitrary strings can't be
 * persisted.
 */
public enum Gender {
    MALE,
    FEMALE,
    OTHER
}
