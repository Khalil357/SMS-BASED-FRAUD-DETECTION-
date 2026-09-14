package com.example.smsfraud.feedback;

import com.example.smsfraud.common.exception.GlobalExceptionHandler;
import com.example.smsfraud.scan.SmsScan;
import jakarta.persistence.EntityManagerFactory;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.DependsOn;
import org.springframework.context.annotation.Import;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.orm.jpa.JpaTransactionManager;
import org.springframework.orm.jpa.LocalContainerEntityManagerFactoryBean;
import org.springframework.orm.jpa.vendor.HibernateJpaVendorAdapter;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.junit.jupiter.SpringJUnitConfig;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.EnableTransactionManagement;
import org.springframework.transaction.support.TransactionTemplate;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;

import javax.sql.DataSource;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Real PostgreSQL, production migrations and Spring-managed JPA transactions; requires Docker. */
@Testcontainers
@SpringJUnitConfig(FraudRecordDatabaseIntegrationTest.DatabaseConfig.class)
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
class FraudRecordDatabaseIntegrationTest {

    @Container
    static final PostgreSQLContainer postgres = new PostgreSQLContainer("postgres:15")
            .withDatabaseName("feedback_integration_test");

    @Autowired
    private FraudRecordRepository repository;

    @Autowired
    private FraudRecordService service;

    @Autowired
    private FraudRecordController controller;

    @Autowired
    private DataSource dataSource;

    @Autowired
    private PlatformTransactionManager transactionManager;

    private JdbcTemplate jdbc;
    private MockMvc mvc;

    @BeforeEach
    void setUp() {
        // Only the disposable container is used; application datasource settings are never loaded.
        repository.deleteAllInBatch();
        jdbc = new JdbcTemplate(dataSource);
        mvc = MockMvcBuilders.standaloneSetup(controller)
                .setControllerAdvice(new GlobalExceptionHandler(), new FeedbackExceptionHandler())
                .build();
    }

    @Test
    void migratesScanSchemaAndGeneratesUuidPrimaryKeys() {
        assertThat(jdbc.queryForObject("SELECT to_regclass('public.sms_fraud_records')::text",
                String.class)).isNull();
        assertThat(jdbc.queryForObject("""
                SELECT count(*) FROM flyway_schema_history
                WHERE version = '3' AND success = true
                """, Long.class)).isEqualTo(1L);
        assertThat(jdbc.queryForObject("""
                SELECT data_type FROM information_schema.columns
                WHERE table_schema = 'public' AND table_name = 'sms_scans' AND column_name = 'scan_id'
                """, String.class)).isEqualTo("uuid");

        SmsScan record = saveFraudScan();

        assertThat(record.getScanId()).isNotNull();
        assertThat(rowCount(record.getScanId())).isEqualTo(1L);
    }

    @Test
    void endpointCommitsDeletionAndPreservesOtherRecords() throws Exception {
        UUID removedId = saveFraudScan().getScanId();
        UUID retainedId = saveFraudScan().getScanId();

        mvc.perform(delete("/api/v1/fraud-records/{recordId}", removedId))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""));

        // A separate JDBC connection observes the commit, independent of JPA's persistence context.
        assertThat(rowCount(removedId)).isZero();
        assertThat(rowCount(retainedId)).isEqualTo(1L);
    }

    @Test
    void missingRecordThrowsDomainExceptionAndReturns404WithoutChangingData() throws Exception {
        UUID missingId = UUID.randomUUID();
        UUID retainedId = saveFraudScan().getScanId();

        assertThatThrownBy(() -> service.deleteRecord(missingId))
                .isInstanceOf(RecordNotFoundException.class)
                .hasMessage("Fraud record with ID " + missingId + " not found.");
        mvc.perform(delete("/api/v1/fraud-records/{recordId}", missingId))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404));

        assertThat(rowCount(retainedId)).isEqualTo(1L);
    }

    @Test
    void repeatedDeletionReturns404() throws Exception {
        UUID recordId = saveFraudScan().getScanId();

        mvc.perform(delete("/api/v1/fraud-records/{recordId}", recordId))
                .andExpect(status().isNoContent());
        mvc.perform(delete("/api/v1/fraud-records/{recordId}", recordId))
                .andExpect(status().isNotFound());

        assertThat(rowCount(recordId)).isZero();
    }

    @Test
    void deletionParticipatesInTransactionAndRollsBackOnFailure() {
        UUID recordId = saveFraudScan().getScanId();
        TransactionTemplate transaction = new TransactionTemplate(transactionManager);

        assertThatThrownBy(() -> transaction.executeWithoutResult(status -> {
            service.deleteRecord(recordId);
            repository.flush();
            assertThat(rowCount(recordId)).isZero();
            throw new IllegalStateException("Simulated failure after deletion");
        })).isInstanceOf(IllegalStateException.class)
                .hasMessage("Simulated failure after deletion");

        assertThat(rowCount(recordId)).isEqualTo(1L);
    }

    private SmsScan saveFraudScan() {
        SmsScan scan = new SmsScan();
        scan.setMessageBody("Test fraud scan for false-positive feedback");
        scan.setVerdict("FRAUD");
        return repository.saveAndFlush(scan);
    }

    private Long rowCount(UUID recordId) {
        return jdbc.queryForObject("SELECT count(*) FROM sms_scans WHERE scan_id = ?",
                Long.class, recordId);
    }

    @Configuration(proxyBeanMethods = false)
    @EnableJpaRepositories(basePackageClasses = FraudRecordRepository.class)
    @EnableTransactionManagement
    @Import({FraudRecordService.class, FraudRecordController.class})
    static class DatabaseConfig {

        @Bean
        DataSource dataSource() {
            return new DriverManagerDataSource(postgres.getJdbcUrl(),
                    postgres.getUsername(), postgres.getPassword());
        }

        @Bean(initMethod = "migrate")
        Flyway flyway(DataSource dataSource) {
            return Flyway.configure().dataSource(dataSource)
                    .locations("classpath:db/migration").load();
        }

        @Bean
        @DependsOn("flyway")
        LocalContainerEntityManagerFactoryBean entityManagerFactory(DataSource dataSource) {
            var factory = new LocalContainerEntityManagerFactoryBean();
            factory.setDataSource(dataSource);
            factory.setPackagesToScan(SmsScan.class.getPackageName());
            factory.setJpaVendorAdapter(new HibernateJpaVendorAdapter());
            // Fail on a mapping/migration mismatch instead of allowing Hibernate to repair it.
            factory.setJpaPropertyMap(Map.of("hibernate.hbm2ddl.auto", "validate"));
            return factory;
        }

        @Bean
        PlatformTransactionManager transactionManager(EntityManagerFactory entityManagerFactory) {
            return new JpaTransactionManager(entityManagerFactory);
        }
    }
}
