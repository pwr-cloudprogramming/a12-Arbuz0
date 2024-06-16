package com.arbuz.tictactoe.controller;

import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.model.PutObjectRequest;
import lombok.AllArgsConstructor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;

@RestController
@AllArgsConstructor
@RequestMapping("/api")
@CrossOrigin(origins = "*")
public class FileUploadController {

    @Autowired
    private AmazonS3 amazonS3;

    @Value("${cloud.aws.s3.bucket}")
    private String bucketName;

    @PostMapping("/upload-profile-pic")
    public ResponseEntity<String> uploadProfilePic(@RequestParam("username") String username, @RequestParam("profilePic") MultipartFile profilePic) {
        String fileName = username + "-profilepic";

        try {
            amazonS3.putObject(new PutObjectRequest(bucketName, fileName, profilePic.getInputStream(), null));
            return ResponseEntity.ok("Profile picture uploaded successfully");
        } catch (IOException e) {
            return ResponseEntity.status(500).body("Failed to upload profile picture");
        }
    }
}
