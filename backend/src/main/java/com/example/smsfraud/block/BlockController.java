package com.example.smsfraud.block;

import com.example.smsfraud.common.dto.ApiResponse;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/api/block")
public class BlockController {

    private final BlockService blockService;

    public BlockController(BlockService blockService) {
        this.blockService = blockService;
    }

    @PostMapping
    public ResponseEntity<ApiResponse<Void>> blockNumber(
            Authentication authentication,
            @Valid @RequestBody BlockRequest req) {
        UUID userId = UUID.fromString(authentication.getName());
        blockService.blockNumber(userId, req.phoneNumber(), req.reason());
        return ResponseEntity.ok(ApiResponse.ok("Number blocked successfully"));
    }

    @DeleteMapping
    public ResponseEntity<ApiResponse<Void>> unblockNumber(
            Authentication authentication,
            @Valid @RequestBody BlockRequest req) {
        UUID userId = UUID.fromString(authentication.getName());
        blockService.unblockNumber(userId, req.phoneNumber());
        return ResponseEntity.ok(ApiResponse.ok("Number unblocked successfully"));
    }

    @GetMapping
    public ResponseEntity<ApiResponse<BlockedListResponse>> getBlockedNumbers(
            Authentication authentication) {
        UUID userId = UUID.fromString(authentication.getName());
        BlockedListResponse response = new BlockedListResponse(
                blockService.getBlockedNumbers(userId));
        return ResponseEntity.ok(ApiResponse.ok("Blocked numbers retrieved", response));
    }
}
