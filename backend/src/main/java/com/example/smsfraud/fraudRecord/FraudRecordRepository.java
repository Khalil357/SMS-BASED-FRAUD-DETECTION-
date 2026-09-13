package com.example.smsfraud.fraudRecord;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

public interface FraudRecordRepository<SmsFraudRecord> extends JpaRepository<SmsFraudRecord, Long>{

}
